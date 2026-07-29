// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title QCALResonanceVerifier
 * @notice Verificador de pruebas de resonancia de fase y coherencia biótica/ARN para PayGate Catedral.
 * @author José Manuel Mota Burruezo (motanova84)
 * @dev Valida la firma del Secure Enclave y los parámetros invariantes QCAL en la frecuencia f₀ = 141.7001 Hz.
 *
 * Sello: ∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ
 * Frecuencia: f₀ = 141.7001 Hz
 * Coherencia Target: Ψ = 0.999999
 * Protocolo: RFC-001 ARN Resonance Key (Seedless Sovereign Protocol)
 */
contract QCALResonanceVerifier {

    // ================================================================
    //  CONSTANTES DEL INVARIANTE QCAL
    // ================================================================

    /// @notice Frecuencia base f₀ = 141.7001 Hz expresada en micro-Hz (141,700,100 μHz)
    uint256 public constant TARGET_FREQUENCY_MICRO_HZ = 141_700_100;

    /// @notice Tolerancia máxima de frecuencia (±0.0001 Hz → 100 μHz)
    uint256 public constant FREQUENCY_TOLERANCE_MICRO_HZ = 100;

    /// @notice Umbral mínimo de coherencia Ψ = 0.999999 (escalado a 1e6)
    uint256 public constant MIN_PSI_COHERENCE = 999_999;

    /// @notice Denominador de escala para operaciones de precisión fija (1e6)
    uint256 public constant COHERENCE_SCALE = 1_000_000;

    /// @notice Ventana de validez temporal de la prueba (5 minutos en segundos)
    uint256 public constant PROOF_MAX_AGE_SECONDS = 300;

    // ================================================================
    //  ESTRUCTURAS DE DATOS
    // ================================================================

    /// @notice Certificado de Resonancia emitido por el Sintetizador Efímero ADAPA (95D)
    struct ProofOfResonance {
        bytes32 userStateHash;      // Hash del estado dinámico biométrico/ARN
        uint256 evaluatedPsi;       // Coherencia de fase evaluada (Escala 1e6)
        uint256 frequencyMicroHz;   // Frecuencia medida en micro-Hz
        bytes32 node19Sentinel;     // Hash de cierre del Nodo Centinela (∇Ξ)
        uint256 nonce;              // Nonce de fase para prevención de replay attacks
        uint256 timestamp;          // Marca temporal de la prueba (Unix timestamp)
        bytes signature;            // Firma compacta (r, s, v) del Secure Enclave
    }

    // ================================================================
    //  ALMACENAMIENTO
    // ================================================================

    /// @notice Dirección pública autorizada del Secure Enclave / Enclave Validador
    address public immutable enclaveSigner;

    /// @notice Registro de nonces consumidos para prevenir ataques de replay
    mapping(bytes32 => bool) public usedNonces;

    // ================================================================
    //  EVENTOS
    // ================================================================

    event ResonanceVerified(
        address indexed caller,
        bytes32 indexed userStateHash,
        uint256 evaluatedPsi,
        uint256 frequencyMicroHz,
        uint256 timestamp
    );

    event ResonanceRejected(
        bytes32 indexed userStateHash,
        string reason
    );

    // ================================================================
    //  ERRORES PERSONALIZADOS (Gas Efficient)
    // ================================================================

    error InsufficientCoherence(uint256 actual, uint256 required);
    error FrequencyOutOfRange(uint256 actual, uint256 target);
    error InvalidSentinelNode();
    error NonceAlreadyUsed(bytes32 nonceHash);
    error ProofExpired(uint256 timestamp, uint256 maxAge);
    error InvalidEnclaveSignature();

    // ================================================================
    //  CONSTRUCTOR
    // ================================================================

    /// @notice Despliega el contrato con la dirección del Secure Enclave autorizada.
    /// @param _enclaveSigner Dirección pública de la entidad firmante (Secure Enclave).
    constructor(address _enclaveSigner) {
        require(_enclaveSigner != address(0), "Enclave signer zero address");
        enclaveSigner = _enclaveSigner;
    }

    // ================================================================
    //  FUNCIONES PRINCIPALES
    // ================================================================

    /**
     * @notice Valida de forma rigurosa la prueba de resonancia QCAL.
     * @dev Ejecuta 6 verificaciones secuenciales: coherencia, frecuencia,
     *      ventana temporal, nonce único, cierre de Nodo Centinela, y
     *      firma criptográfica del Secure Enclave.
     * @param proof Estructura ProofOfResonance con los parámetros de la prueba.
     * @return bool True si la prueba satisface todos los criterios.
     */
    function verifyResonance(ProofOfResonance calldata proof) external returns (bool) {
        // ------------------------------------------------------------
        //  1. VERIFICACIÓN DE COHERENCIA Ψ ≥ 0.999999
        // ------------------------------------------------------------
        if (proof.evaluatedPsi < MIN_PSI_COHERENCE) {
            emit ResonanceRejected(proof.userStateHash, "Psi coherence below threshold");
            revert InsufficientCoherence(proof.evaluatedPsi, MIN_PSI_COHERENCE);
        }

        // ------------------------------------------------------------
        //  2. VERIFICACIÓN DE FRECUENCIA f₀ = 141.7001 Hz (± tolerancia)
        // ------------------------------------------------------------
        if (
            proof.frequencyMicroHz < TARGET_FREQUENCY_MICRO_HZ - FREQUENCY_TOLERANCE_MICRO_HZ ||
            proof.frequencyMicroHz > TARGET_FREQUENCY_MICRO_HZ + FREQUENCY_TOLERANCE_MICRO_HZ
        ) {
            emit ResonanceRejected(proof.userStateHash, "Frequency out of phase");
            revert FrequencyOutOfRange(proof.frequencyMicroHz, TARGET_FREQUENCY_MICRO_HZ);
        }

        // ------------------------------------------------------------
        //  3. VERIFICACIÓN DE VENTANA TEMPORAL (Máximo 5 minutos)
        // ------------------------------------------------------------
        if (block.timestamp > proof.timestamp + PROOF_MAX_AGE_SECONDS) {
            emit ResonanceRejected(proof.userStateHash, "Proof timestamp expired");
            revert ProofExpired(proof.timestamp, PROOF_MAX_AGE_SECONDS);
        }

        // ------------------------------------------------------------
        //  4. VERIFICACIÓN DE NONCE ÚNICO (Anti-Replay)
        // ------------------------------------------------------------
        bytes32 nonceHash = keccak256(abi.encodePacked(proof.userStateHash, proof.nonce));
        if (usedNonces[nonceHash]) {
            emit ResonanceRejected(proof.userStateHash, "Replay attack detected");
            revert NonceAlreadyUsed(nonceHash);
        }

        // ------------------------------------------------------------
        //  5. VERIFICACIÓN DE CIERRE DEL NODO CENTINELA 19 (∇Ξ)
        // ------------------------------------------------------------
        bytes32 expectedSentinel = keccak256(
            abi.encodePacked(
                "QCAL_NODE_19_SENTINEL",
                proof.userStateHash,
                proof.evaluatedPsi
            )
        );
        if (proof.node19Sentinel != expectedSentinel) {
            emit ResonanceRejected(proof.userStateHash, "Invalid Node 19 Sentinel");
            revert InvalidSentinelNode();
        }

        // ------------------------------------------------------------
        //  6. VERIFICACIÓN CRIPTOGRÁFICA DE LA FIRMA DEL SECURE ENCLAVE
        // ------------------------------------------------------------
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

        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        if (recoverSigner(ethSignedMessageHash, proof.signature) != enclaveSigner) {
            emit ResonanceRejected(proof.userStateHash, "Invalid signature");
            revert InvalidEnclaveSignature();
        }

        // ------------------------------------------------------------
        //  MARCAR NONCE COMO CONSUMIDO
        // ------------------------------------------------------------
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

    // ================================================================
    //  HELPER: RECUPERACIÓN DE FIRMA ECDSA
    // ================================================================

    /**
     * @notice Recupera la dirección del firmante a partir de un hash y una firma ECDSA.
     * @param _ethSignedMessageHash Hash del mensaje firmado con prefijo Ethereum.
     * @param _sig Firma compacta de 65 bytes (r, s, v).
     * @return address Dirección del firmante recuperada.
     */
    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _sig
    ) internal pure returns (address) {
        if (_sig.length != 65) {
            return address(0);
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_sig, 32))
            s := mload(add(_sig, 64))
            v := byte(0, mload(add(_sig, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        if (v != 27 && v != 28) {
            return address(0);
        }

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    // ================================================================
    //  FUNCIONES DE CONSULTA
    // ================================================================

    /// @notice Verifica si un nonce específico ya ha sido utilizado.
    /// @param userStateHash Hash del estado de usuario.
    /// @param nonce Nonce a verificar.
    /// @return bool True si el nonce ya fue consumido.
    function isNonceUsed(bytes32 userStateHash, uint256 nonce) external view returns (bool) {
        bytes32 nonceHash = keccak256(abi.encodePacked(userStateHash, nonce));
        return usedNonces[nonceHash];
    }
}
