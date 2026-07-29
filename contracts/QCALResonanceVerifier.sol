// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title QCALResonanceVerifier
 * @notice Verifies ProofOfResonance for the QCAL Sovereign Vault protocol.
 * @dev Validates Ψ-coherency (≥ 0.999999), frequency (f₀ = 141.7001 Hz ± 0.001),
 *      and Node 19 sentinel nonce uniqueness.
 *
 * Sello: ∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ
 * f₀ = 141.7001 Hz
 */
contract QCALResonanceVerifier {
    // ──────────────────────────────────────────────
    //  Constants
    // ──────────────────────────────────────────────

    /// @notice Base frequency f₀ = 141.7001 Hz, expressed in μHz (1e6 scale)
    uint256 public constant F0_MICRO_HZ = 141_700_100;

    /// @notice Frequency tolerance: ±0.001 Hz = ±1000 μHz
    uint256 public constant FREQUENCY_TOLERANCE = 1000;

    /// @notice Minimum Ψ coherency (scaled by 1e6): 0.999999 → 999999
    uint256 public constant MIN_PSI = 999_999;

    /// @notice Maximum Ψ coherency: 1.000000 → 1_000_000
    uint256 public constant MAX_PSI = 1_000_000;

    /// @notice Ψ scale factor (1e6)
    uint256 public constant PSI_SCALE = 1_000_000;

    /// @notice Sello del protocolo
    string public constant SELLO = "∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ";

    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    /**
     * @notice Proof of Resonance struct for on-chain verification.
     * @param userStateHash Hash of the user's state (32 bytes)
     * @param evaluatedPsi Evaluated Ψ coherency (scaled by 1e6, e.g., 999999 = 0.999999)
     * @param frequencyHz Measured frequency in μHz (e.g., 141700100 = 141.7001 Hz)
     * @param node19Sentinel Node 19 sentinel hash from ADAPA reduction
     * @param signature Optional ECDSA signature for future ZK extension
     */
    struct ProofOfResonance {
        bytes32 userStateHash;
        uint256 evaluatedPsi;
        uint256 frequencyHz;
        bytes32 node19Sentinel;
        bytes signature;
    }

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice Track used nonces (node19Sentinel) for replay protection
    mapping(bytes32 => bool) public usedNonces;

    /// @notice Contract owner
    address public owner;

    /// @notice Whether the contract is paused
    bool public paused;

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    /// @notice Emitted when a resonance proof is verified successfully
    event ResonanceVerified(
        bytes32 indexed userStateHash,
        uint256 evaluatedPsi,
        uint256 frequencyHz,
        bytes32 node19Sentinel,
        address indexed verifier,
        uint256 timestamp
    );

    /// @notice Emitted when verification fails
    event ResonanceRejected(
        bytes32 indexed userStateHash,
        string reason
    );

    /// @notice Emitted when nonce is replayed
    event NonceReplayAttempt(
        bytes32 indexed node19Sentinel,
        address indexed attacker
    );

    // ──────────────────────────────────────────────
    //  Errors
    // ──────────────────────────────────────────────

    error PsiBelowThreshold(uint256 evaluated, uint256 minimum);
    error FrequencyOutOfTolerance(uint256 measured, uint256 expected, uint256 tolerance);
    error NonceAlreadyUsed(bytes32 nonce);
    error ContractPaused();
    error Unauthorized();

    // ──────────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ──────────────────────────────────────────────
    //  Core Verification
    // ──────────────────────────────────────────────

    /**
     * @notice Verify a ProofOfResonance against the protocol invariants.
     * @param proof The ProofOfResonance struct
     * @return bool True if the proof is valid
     *
     * Requirements:
     * - evaluatedPsi >= 999_999 (scaled, i.e., Ψ >= 0.999999)
     * - evaluatedPsi <= 1_000_000 (scaled, i.e., Ψ <= 1.0)
     * - frequencyHz within ±1000 μHz of F0_MICRO_HZ (tolerance ±0.001 Hz)
     * - node19Sentinel not previously used (anti-replay)
     */
    function verifyResonance(
        ProofOfResonance memory proof
    ) external whenNotPaused returns (bool) {
        // 1. Validate Ψ coherency
        if (proof.evaluatedPsi < MIN_PSI) {
            emit ResonanceRejected(proof.userStateHash, "Psi below threshold");
            revert PsiBelowThreshold(proof.evaluatedPsi, MIN_PSI);
        }

        if (proof.evaluatedPsi > MAX_PSI) {
            emit ResonanceRejected(proof.userStateHash, "Psi exceeds max");
            revert PsiBelowThreshold(proof.evaluatedPsi, MAX_PSI);
        }

        // 2. Validate base frequency
        uint256 diff;
        if (proof.frequencyHz > F0_MICRO_HZ) {
            diff = proof.frequencyHz - F0_MICRO_HZ;
        } else {
            diff = F0_MICRO_HZ - proof.frequencyHz;
        }

        if (diff > FREQUENCY_TOLERANCE) {
            emit ResonanceRejected(proof.userStateHash, "Frequency out of tolerance");
            revert FrequencyOutOfTolerance(proof.frequencyHz, F0_MICRO_HZ, FREQUENCY_TOLERANCE);
        }

        // 3. Check nonce uniqueness (Node 19 sentinel as nonce)
        if (usedNonces[proof.node19Sentinel]) {
            emit NonceReplayAttempt(proof.node19Sentinel, msg.sender);
            revert NonceAlreadyUsed(proof.node19Sentinel);
        }

        // 4. Mark nonce as used
        usedNonces[proof.node19Sentinel] = true;

        // 5. Emit success event
        emit ResonanceVerified(
            proof.userStateHash,
            proof.evaluatedPsi,
            proof.frequencyHz,
            proof.node19Sentinel,
            msg.sender,
            block.timestamp
        );

        return true;
    }

    /**
     * @notice Check if a proof would be valid without consuming the nonce.
     * @param proof The ProofOfResonance struct
     * @return bool True if the proof would pass verification
     */
    function previewVerification(
        ProofOfResonance memory proof
    ) external view returns (bool) {
        if (proof.evaluatedPsi < MIN_PSI || proof.evaluatedPsi > MAX_PSI) {
            return false;
        }

        uint256 diff;
        if (proof.frequencyHz > F0_MICRO_HZ) {
            diff = proof.frequencyHz - F0_MICRO_HZ;
        } else {
            diff = F0_MICRO_HZ - proof.frequencyHz;
        }

        if (diff > FREQUENCY_TOLERANCE) {
            return false;
        }

        if (usedNonces[proof.node19Sentinel]) {
            return false;
        }

        return true;
    }

    // ──────────────────────────────────────────────
    //  Admin
    // ──────────────────────────────────────────────

    /**
     * @notice Pause or unpause the contract.
     * @param _paused Whether to pause
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    /**
     * @notice Transfer ownership.
     * @param newOwner Address of new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}
