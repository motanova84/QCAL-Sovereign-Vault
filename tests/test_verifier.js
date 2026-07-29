const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("QCALResonanceVerifier", function () {
    let verifier;
    let enclaveSigner;
    let user;
    let attacker;

    const TARGET_FREQUENCY_MICRO_HZ = 141_700_100n;
    const MIN_PSI_COHERENCE = 999_999n;
    const PROOF_MAX_AGE_SECONDS = 300n;

    before(async function () {
        [enclaveSigner, user, attacker] = await ethers.getSigners();
    });

    // ─────────────────────────────────────────────────────────────
    //  Helper: crear una prueba firmada por el enclave
    // ─────────────────────────────────────────────────────────────
    async function createSignedProof(overrides = {}) {
        const signer = overrides.signer || enclaveSigner;
        const userStateHash = overrides.userStateHash || ethers.randomBytes(32);
        const evaluatedPsi = overrides.evaluatedPsi ?? MIN_PSI_COHERENCE;
        const frequencyMicroHz = overrides.frequencyMicroHz ?? TARGET_FREQUENCY_MICRO_HZ;
        const nonce = overrides.nonce ?? Math.floor(Math.random() * 1e12);
        const timestamp = overrides.timestamp ?? Math.floor(Date.now() / 1000);

        const node19Sentinel = ethers.solidityPackedKeccak256(
            ["string", "bytes32", "uint256"],
            ["QCAL_NODE_19_SENTINEL", userStateHash, evaluatedPsi]
        );

        const messageHash = ethers.solidityPackedKeccak256(
            ["bytes32", "uint256", "uint256", "bytes32", "uint256", "uint256", "uint256"],
            [userStateHash, evaluatedPsi, frequencyMicroHz, node19Sentinel, nonce, timestamp, 31337n] // chainId hardhat
        );

        const signature = await signer.signMessage(ethers.getBytes(messageHash));

        return {
            proof: {
                userStateHash,
                evaluatedPsi,
                frequencyMicroHz,
                node19Sentinel,
                nonce,
                timestamp,
                signature,
            },
        };
    }

    // ═════════════════════════════════════════════════════════════
    //  SECCIÓN 1: INICIALIZACIÓN E INVARIANTES
    // ═════════════════════════════════════════════════════════════

    describe("1. Inicializacion e Invariantes", function () {
        it("Debe configurar correctamente la direccion del Secure Enclave", async function () {
            const Verifier = await ethers.getContractFactory("QCALResonanceVerifier");
            verifier = await Verifier.deploy(enclaveSigner.address);
            await verifier.waitForDeployment();

            expect(await verifier.enclaveSigner()).to.equal(enclaveSigner.address);
        });

        it("Debe exponer las constantes correctas del marco QCAL", async function () {
            expect(await verifier.TARGET_FREQUENCY_MICRO_HZ()).to.equal(TARGET_FREQUENCY_MICRO_HZ);
            expect(await verifier.MIN_PSI_COHERENCE()).to.equal(MIN_PSI_COHERENCE);
            expect(await verifier.PROOF_MAX_AGE_SECONDS()).to.equal(PROOF_MAX_AGE_SECONDS);
        });
    });

    // ═════════════════════════════════════════════════════════════
    //  SECCIÓN 2: VALIDACIÓN EXITOSA
    // ═════════════════════════════════════════════════════════════

    describe("2. Validacion Exitosa", function () {
        it("Debe aceptar una prueba valida y emitir el evento ResonanceVerified", async function () {
            const { proof } = await createSignedProof();

            await expect(verifier.verifyResonance(proof))
                .to.emit(verifier, "ResonanceVerified")
                .withArgs(user.address, proof.userStateHash, proof.evaluatedPsi, proof.frequencyMicroHz, proof.timestamp);

            // El nonce debe quedar registrado como usado
            const nonceHash = ethers.solidityPackedKeccak256(
                ["bytes32", "uint256"],
                [proof.userStateHash, proof.nonce]
            );
            expect(await verifier.usedNonces(nonceHash)).to.equal(true);
        });
    });

    // ═════════════════════════════════════════════════════════════
    //  SECCIÓN 3: VALIDACIÓN DE RECHAZOS
    // ═════════════════════════════════════════════════════════════

    describe("3. Rechazo por Coherencia, Frecuencia y Sentinel", function () {
        it("Debe rechazar cuando Ψ < 0.999999", async function () {
            const { proof } = await createSignedProof({ evaluatedPsi: 900_000 });
            await expect(verifier.verifyResonance(proof))
                .to.be.revertedWithCustomError(verifier, "InsufficientCoherence")
                .withArgs(900_000, MIN_PSI_COHERENCE);
        });

        it("Debe rechazar cuando f₀ ≠ 141.7001 Hz", async function () {
            const { proof } = await createSignedProof({ frequencyMicroHz: 140_000_000 });
            await expect(verifier.verifyResonance(proof))
                .to.be.revertedWithCustomError(verifier, "FrequencyOutOfRange")
                .withArgs(140_000_000, TARGET_FREQUENCY_MICRO_HZ);
        });

        it("Debe rechazar cuando el cierre del Nodo Centinela 19 (∇Ξ) es invalido", async function () {
            const invalidSentinel = ethers.solidityPackedKeccak256(["string"], ["BAD_SENTINEL"]);
            const { proof } = await createSignedProof({ node19Sentinel: invalidSentinel });
            await expect(verifier.verifyResonance(proof))
                .to.be.revertedWithCustomError(verifier, "InvalidSentinelNode");
        });
    });

    // ═════════════════════════════════════════════════════════════
    //  SECCIÓN 4: SEGURIDAD Y CRIPTOGRAFÍA
    // ═════════════════════════════════════════════════════════════

    describe("4. Seguridad y Criptografia", function () {
        it("Debe prevenir ataques de Replay utilizando el mismo nonce", async function () {
            const { proof } = await createSignedProof();
            await verifier.verifyResonance(proof);

            const nonceHash = ethers.solidityPackedKeccak256(
                ["bytes32", "uint256"],
                [proof.userStateHash, proof.nonce]
            );
            await expect(verifier.verifyResonance(proof))
                .to.be.revertedWithCustomError(verifier, "NonceAlreadyUsed")
                .withArgs(nonceHash);
        });

        it("Debe rechazar certificados expirados (antiguedad > 5 minutos)", async function () {
            const latestBlock = await ethers.provider.getBlock("latest");
            const expiredTimestamp = BigInt(latestBlock.timestamp) - 301n;
            const { proof } = await createSignedProof({ timestamp: expiredTimestamp });
            await expect(verifier.verifyResonance(proof))
                .to.be.revertedWithCustomError(verifier, "ProofExpired")
                .withArgs(expiredTimestamp, PROOF_MAX_AGE_SECONDS);
        });

        it("Debe rechazar firmas provenientes de cuentas no autorizadas", async function () {
            const { proof } = await createSignedProof({ signer: user });
            await expect(verifier.verifyResonance(proof))
                .to.be.revertedWithCustomError(verifier, "InvalidEnclaveSignature");
        });
    });
});
