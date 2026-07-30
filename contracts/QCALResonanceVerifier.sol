// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title QCALResonanceVerifier
 * @notice Verificador de resonancia cuántica para el ecosistema QCAL ∞³
 * @author José Manuel Mota Burruezo (motanova84) — ICQ
 * @dev Frecuencia fundamental: f₀ = 141.7001 Hz | Coherencia mínima: Ψ = 0.999999
 *
 * Sello: ∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ
 */
contract QCALResonanceVerifier {
    using ECDSA for bytes32;
    

    // ═══════════════════════════════════════════════════════════════════════
    //  CONSTANTES DE INVARIANTE QCAL
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Frecuencia base f₀ = 141.7001 Hz expresada en micro-Hz
    uint256 public constant TARGET_FREQUENCY_MICRO_HZ = 141_700_100;

    /// @notice Umbral mínimo de coherencia Ψ = 0.999999 (escala 1e6)
    uint256 public constant MIN_PSI_COHERENCE = 999_999;

    /// @notice Ventana de validez temporal (5 minutos en segundos)
    uint256 public constant PROOF_MAX_AGE_SECONDS = 300;

    // ═══════════════════════════════════════════════════════════════════════
    //  ESTADO
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Dirección pública del Secure Enclave autorizado para firmar
    address public immutable enclaveSigner;

    /// @notice Registro de nonces consumidos (anti-replay)
    mapping(bytes32 => bool) public usedNonces;

    // ═══════════════════════════════════════════════════════════════════════
    //  ESTRUCTURAS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Certificado de Resonancia emitido por el Sintetizador ADAPA (95D)
    struct Proof {
        bytes32 userStateHash;      // Hash del estado biométrico/ARN
        uint256 evaluatedPsi;       // Coherencia de fase (escala 1e6)
        uint256 frequencyMicroHz;   // Frecuencia en micro-Hz
        bytes32 node19Sentinel;     // Hash del Nodo Centinela 19 (∇Ξ)
        uint256 nonce;              // Nonce de fase anti-replay
        uint256 timestamp;          // Unix timestamp de generación
        bytes signature;            // Firma ECDSA del Secure Enclave
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  EVENTOS
    // ═══════════════════════════════════════════════════════════════════════

    event ResonanceVerified(
        address indexed user,
        bytes32 indexed userStateHash,
        uint256 evaluatedPsi,
        uint256 frequencyMicroHz,
        uint256 timestamp
    );

    // ═══════════════════════════════════════════════════════════════════════
    //  ERRORES PERSONALIZADOS (Gas Efficient)
    // ═══════════════════════════════════════════════════════════════════════

    error InsufficientCoherence(uint256 provided, uint256 required);
    error FrequencyOutOfRange(uint256 provided, uint256 target);
    error InvalidSentinelNode();
    error NonceAlreadyUsed(bytes32 nonceHash);
    error ProofExpired(uint256 provided, uint256 maxAge);
    error InvalidEnclaveSignature();

    // ═══════════════════════════════════════════════════════════════════════
    //  CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    /// @param _enclaveSigner Dirección pública del Secure Enclave autorizado
    constructor(address _enclaveSigner) {
        require(_enclaveSigner != address(0), "Enclave: direccion nula");
        enclaveSigner = _enclaveSigner;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  FUNCIÓN PRINCIPAL DE VERIFICACIÓN
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @notice Verifica un certificado de resonancia emitido por el Secure Enclave.
     * @dev Ejecuta 6 verificaciones secuenciales. Revert en la primera que falle.
     * @param proof Estructura Proof con los parámetros firmados por el enclave.
     */
    function verifyResonance(Proof calldata proof) external returns (bool) {
        // ── 1. Validación de coherencia Ψ ≥ 0.999999 ─────────────
        if (proof.evaluatedPsi < MIN_PSI_COHERENCE) {
            revert InsufficientCoherence(proof.evaluatedPsi, MIN_PSI_COHERENCE);
        }

        // ── 2. Validación de frecuencia f₀ = 141.7001 Hz ─────────
        if (proof.frequencyMicroHz != TARGET_FREQUENCY_MICRO_HZ) {
            revert FrequencyOutOfRange(proof.frequencyMicroHz, TARGET_FREQUENCY_MICRO_HZ);
        }

        // ── 3. Validación del Nodo Centinela 19 (∇Ξ) ────────────
        bytes32 expectedSentinel = keccak256(
            abi.encodePacked("QCAL_NODE_19_SENTINEL", proof.userStateHash, proof.evaluatedPsi)
        );
        if (proof.node19Sentinel != expectedSentinel) {
            revert InvalidSentinelNode();
        }

        // ── 4. Prevención de Replay ─────────────────────────────
        bytes32 nonceHash = keccak256(abi.encodePacked(proof.userStateHash, proof.nonce));
        if (usedNonces[nonceHash]) {
            revert NonceAlreadyUsed(nonceHash);
        }

        // ── 5. Validación temporal (máx 5 min de antigüedad) ────
        if (block.timestamp > proof.timestamp + PROOF_MAX_AGE_SECONDS) {
            revert ProofExpired(proof.timestamp, PROOF_MAX_AGE_SECONDS);
        }
        // Nota: No se rechazan timestamps futuros para permitir
        // desfases de reloj entre dispositivos.

        // ── 6. Validación de firma ECDSA del Secure Enclave ─────
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                proof.userStateHash,
                proof.evaluatedPsi,
                proof.frequencyMicroHz,
                proof.node19Sentinel,
                proof.nonce,
                proof.timestamp,
                block.chainid
            )
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address recovered = ethSignedHash.recover(proof.signature);
        if (recovered != enclaveSigner) {
            revert InvalidEnclaveSignature();
        }

        // ── Marcar nonce como consumido ────────────────────────
        usedNonces[nonceHash] = true;

        emit ResonanceVerified(
            msg.sender,
            proof.userStateHash,
            proof.evaluatedPsi,
            proof.frequencyMicroHz,
            proof.timestamp
        );
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  FUNCIONES DE CONSULTA
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Verifica si un nonce específico ya ha sido consumido.
    function isNonceUsed(bytes32 userStateHash, uint256 nonce) external view returns (bool) {
        bytes32 nonceHash = keccak256(abi.encodePacked(userStateHash, nonce));
        return usedNonces[nonceHash];
    }
}
