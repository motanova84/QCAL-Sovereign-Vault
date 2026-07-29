/**
 * test_verifier.js — Hardhat/Foundry test stub for QCAL contracts
 * QCAL Sovereign Vault — C∞³ Seedless Self-Custody Protocol
 *
 * Tests QCALResonanceVerifier and PayGateCatedral contracts.
 *
 * Prerequisites:
 *   npm install --save-dev hardhat ethers @nomicfoundation/hardhat-toolbox
 *
 * Sello: ∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ
 */

const { expect } = require("chai");
const { ethers } = require("hardhat");

// ── Constants ──────────────────────────────────────────────────────

const F0_MICRO_HZ = 141700100n;   // 141.7001 Hz * 1e6
const FREQ_TOLERANCE = 1000n;     // ±0.001 Hz
const MIN_PSI = 999999n;          // Ψ ≥ 0.999999 (scaled 1e6)
const MAX_PSI = 1000000n;         // Ψ ≤ 1.0 (scaled 1e6)
const SELLO = "∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ";

// ── Helpers ────────────────────────────────────────────────────────

/**
 * Generate a valid ProofOfResonance struct for testing.
 */
function makeValidProof(overrides = {}) {
    return {
        userStateHash: overrides.userStateHash || ethers.hexlify(ethers.randomBytes(32)),
        evaluatedPsi: overrides.evaluatedPsi ?? MIN_PSI,
        frequencyHz: overrides.frequencyHz ?? F0_MICRO_HZ,
        node19Sentinel: overrides.node19Sentinel || ethers.hexlify(ethers.randomBytes(32)),
        signature: overrides.signature || "0x",
    };
}

// ── QCALResonanceVerifier Tests ────────────────────────────────────

describe("QCALResonanceVerifier", function () {
    let verifier;
    let owner;
    let user;

    beforeEach(async function () {
        [owner, user] = await ethers.getSigners();
        const Verifier = await ethers.getContractFactory("QCALResonanceVerifier");
        verifier = await Verifier.deploy();
    });

    describe("Deployment", function () {
        it("should set the correct owner", async function () {
            expect(await verifier.owner()).to.equal(owner.address);
        });

        it("should have the correct constants", async function () {
            expect(await verifier.F0_MICRO_HZ()).to.equal(F0_MICRO_HZ);
            expect(await verifier.MIN_PSI()).to.equal(MIN_PSI);
            expect(await verifier.SELLO()).to.equal(SELLO);
        });

        it("should start unpaused", async function () {
            expect(await verifier.paused()).to.equal(false);
        });
    });

    describe("verifyResonance", function () {
        it("should accept a valid ProofOfResonance", async function () {
            const proof = makeValidProof();
            const tx = await verifier.verifyResonance(proof);
            await expect(tx).to.emit(verifier, "ResonanceVerified");
        });

        it("should reject Ψ below threshold", async function () {
            const proof = makeValidProof({ evaluatedPsi: 999998 }); // Just below 0.999999
            await expect(
                verifier.verifyResonance(proof)
            ).to.be.revertedWithCustomError(verifier, "PsiBelowThreshold");
        });

        it("should reject Ψ above maximum", async function () {
            const proof = makeValidProof({ evaluatedPsi: 1000001n }); // Above 1.0
            await expect(
                verifier.verifyResonance(proof)
            ).to.be.revertedWithCustomError(verifier, "PsiBelowThreshold");
        });

        it("should reject frequency too high", async function () {
            const proof = makeValidProof({ frequencyHz: F0_MICRO_HZ + FREQ_TOLERANCE + 1n });
            await expect(
                verifier.verifyResonance(proof)
            ).to.be.revertedWithCustomError(verifier, "FrequencyOutOfTolerance");
        });

        it("should reject frequency too low", async function () {
            const proof = makeValidProof({ frequencyHz: F0_MICRO_HZ - FREQ_TOLERANCE - 1n });
            await expect(
                verifier.verifyResonance(proof)
            ).to.be.revertedWithCustomError(verifier, "FrequencyOutOfTolerance");
        });

        it("should accept frequency at tolerance boundary (high)", async function () {
            const proof = makeValidProof({ frequencyHz: F0_MICRO_HZ + FREQ_TOLERANCE });
            await expect(
                verifier.verifyResonance(proof)
            ).to.emit(verifier, "ResonanceVerified");
        });

        it("should accept frequency at tolerance boundary (low)", async function () {
            const proof = makeValidProof({ frequencyHz: F0_MICRO_HZ - FREQ_TOLERANCE });
            await expect(
                verifier.verifyResonance(proof)
            ).to.emit(verifier, "ResonanceVerified");
        });

        it("should reject duplicate nonce (node19Sentinel)", async function () {
            const node19Sentinel = ethers.hexlify(ethers.randomBytes(32));
            const proof1 = makeValidProof({ node19Sentinel });
            const proof2 = makeValidProof({ node19Sentinel });

            // First should succeed
            await verifier.verifyResonance(proof1);

            // Second with same nonce should fail
            await expect(
                verifier.verifyResonance(proof2)
            ).to.be.revertedWithCustomError(verifier, "NonceAlreadyUsed");
        });

        it("should track used nonces", async function () {
            const proof = makeValidProof();
            await verifier.verifyResonance(proof);
            expect(await verifier.usedNonces(proof.node19Sentinel)).to.equal(true);
        });

        it("should allow different nonces from same user", async function () {
            const proof1 = makeValidProof();
            const proof2 = makeValidProof();
            await verifier.verifyResonance(proof1);
            await expect(
                verifier.verifyResonance(proof2)
            ).to.emit(verifier, "ResonanceVerified");
        });

        it("should revert when contract is paused", async function () {
            await verifier.setPaused(true);
            const proof = makeValidProof();
            await expect(
                verifier.verifyResonance(proof)
            ).to.be.revertedWithCustomError(verifier, "ContractPaused");
        });
    });

    describe("previewVerification", function () {
        it("should return true for a valid proof", async function () {
            const proof = makeValidProof();
            expect(await verifier.previewVerification(proof)).to.equal(true);
        });

        it("should return false for Ψ below threshold", async function () {
            const proof = makeValidProof({ evaluatedPsi: 500000 });
            expect(await verifier.previewVerification(proof)).to.equal(false);
        });

        it("should return false for frequency out of tolerance", async function () {
            const proof = makeValidProof({ frequencyHz: 150000000n });
            expect(await verifier.previewVerification(proof)).to.equal(false);
        });

        it("should return false for used nonce", async function () {
            const proof = makeValidProof();
            await verifier.verifyResonance(proof);
            expect(await verifier.previewVerification(proof)).to.equal(false);
        });
    });

    describe("Admin", function () {
        it("should allow owner to pause", async function () {
            await verifier.setPaused(true);
            expect(await verifier.paused()).to.equal(true);
        });

        it("should allow owner to unpause", async function () {
            await verifier.setPaused(true);
            await verifier.setPaused(false);
            expect(await verifier.paused()).to.equal(false);
        });

        it("should reject non-owner pause attempts", async function () {
            await expect(
                verifier.connect(user).setPaused(true)
            ).to.be.revertedWithCustomError(verifier, "Unauthorized");
        });
    });
});


// ── PayGateCatedral Tests ──────────────────────────────────────────

describe("PayGateCatedral", function () {
    let verifier;
    let paygate;
    let owner;
    let manager;
    let user;

    beforeEach(async function () {
        [owner, manager, user] = await ethers.getSigners();

        // Deploy verifier
        const Verifier = await ethers.getContractFactory("QCALResonanceVerifier");
        verifier = await Verifier.deploy();

        // Deploy paygate
        const PayGate = await ethers.getContractFactory("PayGateCatedral");
        paygate = await PayGate.deploy(await verifier.getAddress());
    });

    describe("Deployment", function () {
        it("should set owner correctly", async function () {
            expect(await paygate.owner()).to.equal(owner.address);
        });

        it("should have 4 initial services", async function () {
            const keys = await paygate.getServiceKeys();
            expect(keys.length).to.equal(4);
            expect(keys).to.include("santuario");
            expect(keys).to.include("oraculo");
            expect(keys).to.include("limpieza");
            expect(keys).to.include("validacion");
        });

        it("should have correct service pricing", async function () {
            const santuario = await paygate.services("santuario");
            expect(santuario.price).to.equal(1000n);
            expect(santuario.active).to.equal(true);

            const oracle = await paygate.services("oraculo");
            expect(oracle.price).to.equal(5000n);

            const validacion = await paygate.services("validacion");
            expect(validacion.price).to.equal(500n);
        });
    });

    describe("Service Management", function () {
        it("should allow manager to create new services", async function () {
            await paygate.setManager(manager.address);
            await paygate.connect(manager).createService("prueba", 100, "Test service");
            const svc = await paygate.services("prueba");
            expect(svc.price).to.equal(100n);
            expect(svc.active).to.equal(true);
        });

        it("should reject duplicate service keys", async function () {
            await paygate.setManager(manager.address);
            await paygate.connect(manager).createService("prueba", 100, "First");
            await expect(
                paygate.connect(manager).createService("prueba", 200, "Duplicate")
            ).to.be.revertedWith("Service already exists");
        });

        it("should allow service updates", async function () {
            await paygate.setManager(manager.address);
            await paygate.connect(manager).updateService("santuario", 2000, true);
            const svc = await paygate.services("santuario");
            expect(svc.price).to.equal(2000n);
        });

        it("should reject non-manager service creation", async function () {
            await expect(
                paygate.connect(user).createService("prueba", 100, "Test")
            ).to.be.revertedWithCustomError(paygate, "Unauthorized");
        });
    });

    describe("Service Purchase", function () {
        it("should reject purchase of non-existent service", async function () {
            const proof = makeValidProof();
            await expect(
                paygate.purchaseService("no_existe", proof, 0, { value: 1000 })
            ).to.be.revertedWithCustomError(paygate, "ServiceNotFound");
        });

        it("should reject purchase with insufficient payment", async function () {
            const proof = makeValidProof();
            await expect(
                paygate.purchaseService("santuario", proof, 0, { value: 500 })
            ).to.be.revertedWithCustomError(paygate, "InsufficientPayment");
        });

        it("should reject purchase without resonance proof", async function () {
            const proof = makeValidProof({ evaluatedPsi: 500000 }); // Invalid
            await expect(
                paygate.purchaseService("santuario", proof, 0, { value: 1000 })
            ).to.be.revertedWithCustomError(verifier, "PsiBelowThreshold");
        });

        it("should reject duplicate purchase of same service", async function () {
            const proof = makeValidProof();
            await paygate.purchaseService("validacion", proof, 3600, { value: 500 });
            const proof2 = makeValidProof();
            await expect(
                paygate.purchaseService("validacion", proof2, 3600, { value: 500 })
            ).to.be.revertedWithCustomError(paygate, "AlreadyActivated");
        });

        it("should accept valid purchase", async function () {
            const proof = makeValidProof();
            const tx = await paygate.purchaseService(
                "validacion",
                proof,
                3600,
                { value: 500 }
            );
            await expect(tx).to.emit(paygate, "ServiceActivated");
        });

        it("should track total collected", async function () {
            const proof1 = makeValidProof();
            const proof2 = makeValidProof({ node19Sentinel: ethers.hexlify(ethers.randomBytes(32)) });

            await paygate.purchaseService("validacion", proof1, 3600, { value: 500 });

            // For duplicate service check — need a different service
            const total = await paygate.totalCollected();
            expect(total).to.equal(500n);
        });
    });

    describe("Activation Tracking", function () {
        it("should report active service after purchase", async function () {
            const proof = makeValidProof();
            await paygate.purchaseService("validacion", proof, 3600, { value: 500 });
            expect(
                await paygate.hasActiveService("validacion", owner.address)
            ).to.equal(true);
        });

        it("should report correct remaining time", async function () {
            const proof = makeValidProof();
            await paygate.purchaseService("validacion", proof, 3600, { value: 500 });
            const remaining = await paygate.remainingTime("validacion", owner.address);
            expect(remaining).to.be.lessThanOrEqual(3600);
            expect(remaining).to.be.greaterThan(3500); // Within 100s
        });

        it("should report no remaining time for inactive service", async function () {
            // Hasn't been purchased yet
            const remaining = await paygate.remainingTime("validacion", user.address);
            expect(remaining).to.equal(0n);
        });
    });
});


// ── Main ───────────────────────────────────────────────────────────

async function main() {
    console.log("QCAL Resonance Verifier — Test Suite");
    console.log("=".repeat(50));
    console.log(`f₀ = ${F0_MICRO_HZ / 1_000_000n} Hz (${F0_MICRO_HZ} μHz)`);
    console.log(`Ψ  ≥ ${Number(MIN_PSI) / 1_000_000}`);
    console.log(`Sello: ${SELLO}`);
    console.log("=".repeat(50));
}

main().catch(console.error);
