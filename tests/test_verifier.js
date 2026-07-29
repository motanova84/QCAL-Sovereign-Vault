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
    //  Helper: generar y firmar una prueba de resonancia
    // ─────────────────────────────────────────────────────────────
    async function createSignedProof(overrides = {}) {
        const signer = overrides.signer || enclaveSigner;
        const userStateHash = overrides.userStateHash || ethers.randomBytes(32);
        const evaluatedPsi = overrides.evaluatedPsi ?? MIN_PSI_COHERENCE;
        const frequencyMicroHz = overrides.frequencyMicroHz ?? TARGET_FREQUENCY_MICRO_HZ;
        const nonce = overrides.nonce ?? BigInt(Math.floor(Math.random() * 1e12));
        const timestamp = overrides.timestamp ?? BigInt(Math.floor(Date.now() / 1000));

        const node19Sentinel = ethers.solidityPackedKeccak256(
            ["string", "bytes32", "uint256"],
            ["QCAL_NODE_19_SENTINEL", userStateHash, evaluatedPsi]
        );

        const messageHash = ethers.solidityPackedKeccak256(
            ["bytes32", "uint256", "uint256", "bytes32", "uint256", "uint256", "uint256"],
            [userStateHash, evaluatedPsi, frequencyMicroHz, node19Sentinel, nonce, timestamp, 31337n]
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
    //  SECCIÓN 2: VALIDACIÓN EXITOSA DE RESONANCIA
    // ═════════════════════════════════════════════════════════════

    describe("2. Validacion Exitosa de Resonancia", function () {
        it("Debe validar exitosamente un certificado valido emitido por el Secure Enclave", async function () {
            const { proof } = await createSignedProof();

            await expect(verifier.connect(user).verifyResonance(proof))
                .to.emit(verifier, "ResonanceVerified")
                .withArgs(user.address, proof.userStateHash, proof.evaluatedPsi, proof.frequencyMicroHz, proof.timestamp);
        });

        it("Debe registrar el nonce como consumido tras la verificacion", async function () {
            const { proof } = await createSignedProof();
            const nonceHash = ethers.solidityPackedKeccak256(
                ["bytes32", "uint256"],
                [proof.userStateHash, proof.nonce]
            );

            expect(await verifier.usedNonces(nonceHash)).to.be.false;
            await verifier.connect(user).verifyResonance(proof);
            expect(await verifier.usedNonces(nonceHash)).to.be.true;
        });
    });

    // ═════════════════════════════════════════════════════════════
    //  SECCIÓN 3: RECHAZO DE PRUEBAS FUERA DE FASE O INCOHERENTES
    // ═════════════════════════════════════════════════════════════

    describe("3. Rechazo por Coherencia, Frecuencia y Sentinel", function () {
        it("Debe revertir si la coherencia Psi es inferior al umbral (Ψ < 0.999999)", async function () {
            const { proof } = await createSignedProof({ evaluatedPsi: 999_998n });
            await expect(verifier.verifyResonance(proof))
                .to.be.revertedWithCustomError(verifier, "InsufficientCoherence")
                .withArgs(999_998n, MIN_PSI_COHERENCE);
        });

        it("Debe revertir si la frecuencia se desvia del objetivo (f₀ ≠ 141.7001 Hz)", async function () {
            const invalidFreq = 141_700_300n;
            const { proof } = await createSignedProof({ frequencyMicroHz: invalidFreq });
            await expect(verifier.verifyResonance(proof))
                .to.be.revertedWithCustomError(verifier, "FrequencyOutOfRange")
                .withArgs(invalidFreq, TARGET_FREQUENCY_MICRO_HZ);
        });

        it("Debe revertir si el cierre del Nodo Centinela 19 (∇Ξ) es invalido", async function () {
            const invalidSentinel = ethers.id("BAD_SENTINEL");
            const { proof } = await createSignedProof({ node19Sentinel: invalidSentinel });
            await expect(verifier.verifyResonance(proof))
                .to.be.revertedWithCustomError(verifier, "InvalidSentinelNode");
        });
    });

    // ═════════════════════════════════════════════════════════════
    //  SECCIÓN 4: PROTECCIONES DE SEGURIDAD Y CRIPTOGRAFÍA
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
                .withArgs(expiredTimestamp, 300n);
        });

        it("Debe rechazar firmas provenientes de cuentas no autorizadas", async function () {
            const { proof } = await createSignedProof({ signer: user });
            await expect(verifier.verifyResonance(proof))
                .to.be.revertedWithCustomError(verifier, "InvalidEnclaveSignature");
        });
    });
});
