// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PayGateCatedral
 * @notice On-chain PayGate for the QCAL Sovereign Vault ecosystem.
 * @dev Provides service pricing, Ψ-proof-based service activation,
 *      and fee distribution to reserved addresses.
 *
 * Sello: ∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ
 * f₀ = 141.7001 Hz
 */

import "./QCALResonanceVerifier.sol";

contract PayGateCatedral {
    // ──────────────────────────────────────────────
    //  Constants
    // ──────────────────────────────────────────────

    /// @notice Sello del protocolo
    string public constant SELLO = unicode"∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ";

    /// @notice Fee denominator for percentage calculations (100% = 10000)
    uint256 public constant FEE_DENOMINATOR = 10000;

    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    /**
     * @notice Service definition
     * @param price Price in satoshis (or smallest unit)
     * @param description Human-readable description
     * @param active Whether the service is currently offered
     * @param createdAt Timestamp when the service was created
     */
    struct Service {
        uint256 price;
        string description;
        bool active;
        uint256 createdAt;
    }

    /**
     * @notice Service activation record
     * @param user Address of the user
     * @param serviceKey Key identifying the service
     * @param activatedAt Timestamp of activation
     * @param expiresAt Timestamp when activation expires
     * @param paymentHash Hash of the payment invoice
     */
    struct Activation {
        address user;
        string serviceKey;
        uint256 activatedAt;
        uint256 expiresAt;
        bytes32 paymentHash;
    }

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice Reference to the Resonance Verifier contract
    QCALResonanceVerifier public verifier;

    /// @notice Service catalogue: key → Service
    mapping(string => Service) public services;

    /// @notice Service keys array for enumeration
    string[] public serviceKeys;

    /// @notice Activation records: serviceKey → user → Activation
    mapping(string => mapping(address => Activation)) public activations;

    /// @notice Reserved addresses for fee distribution
    address[] public reservedAddresses;

    /// @notice Fee percentages for each reserved address (basis points)
    mapping(address => uint256) public feeShares;

    /// @notice Total collected fees per reserved address
    mapping(address => uint256) public collectedFees;

    /// @notice Contract owner
    address public owner;

    /// @notice Contract manager (can manage services)
    address public manager;

    /// @notice Whether the contract is paused
    bool public paused;

    /// @notice Total satoshis collected
    uint256 public totalCollected;

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    event ServiceCreated(string indexed key, uint256 price, string description);
    event ServiceUpdated(string indexed key, uint256 price, bool active);
    event ServiceActivated(
        string indexed serviceKey,
        address indexed user,
        bytes32 paymentHash,
        uint256 amount,
        uint256 expiresAt
    );
    event FeeDistributed(address indexed recipient, uint256 amount);
    event ReservedAddressAdded(address indexed addr, uint256 share);

    // ──────────────────────────────────────────────
    //  Errors
    // ──────────────────────────────────────────────

    error ServiceNotFound(string key);
    error ServiceNotActive(string key);
    error InsufficientPayment(uint256 required, uint256 provided);
    error AlreadyActivated(string key, address user);
    error ContractPaused();
    error Unauthorized();
    error InvalidFeeDistribution(uint256 totalShares);

    // ──────────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyManager() {
        if (msg.sender != owner && msg.sender != manager) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    constructor(address _verifier) {
        owner = msg.sender;
        verifier = QCALResonanceVerifier(_verifier);

        // Initialize core services
        _createService("santuario", 1000,   unicode"Santuario — espacio soberano (24h)");
        _createService("oraculo",   5000,   unicode"Oráculo — patrón de red y predicciones");
        _createService("limpieza",  0,      unicode"Limpieza — rebalanceo de canales (dinámico)");
        _createService("validacion", 500,   unicode"Check Ψ — verificación de coherencia");
    }

    // ──────────────────────────────────────────────
    //  Service Management
    // ──────────────────────────────────────────────

    /**
     * @notice Create a new service.
     * @param key Service key identifier
     * @param price Price in satoshis
     * @param description Human-readable description
     */
    function createService(
        string memory key,
        uint256 price,
        string memory description
    ) external onlyManager whenNotPaused {
        _createService(key, price, description);
    }

    function _createService(
        string memory key,
        uint256 price,
        string memory description
    ) internal {
        require(bytes(key).length > 0, "Key cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(services[key].createdAt == 0, "Service already exists");

        services[key] = Service({
            price: price,
            description: description,
            active: true,
            createdAt: block.timestamp
        });
        serviceKeys.push(key);

        emit ServiceCreated(key, price, description);
    }

    /**
     * @notice Update an existing service.
     * @param key Service key
     * @param price New price
     * @param active Whether the service is active
     */
    function updateService(
        string memory key,
        uint256 price,
        bool active
    ) external onlyManager whenNotPaused {
        if (services[key].createdAt == 0) revert ServiceNotFound(key);
        services[key].price = price;
        services[key].active = active;
        emit ServiceUpdated(key, price, active);
    }

    /**
     * @notice Get the service catalogue.
     * @return keys Array of service keys
     */
    function getServiceKeys() external view returns (string[] memory) {
        return serviceKeys;
    }

    // ──────────────────────────────────────────────
    //  Service Purchase
    // ──────────────────────────────────────────────

    /**
     * @notice Purchase a service with a ProofOfResonance.
     * @param serviceKey Service to purchase
     * @param proof ProofOfResonance struct
     * @param duration Duration of activation in seconds (0 = service default)
     */
    function purchaseService(
        string memory serviceKey,
        QCALResonanceVerifier.ProofOfResonance memory proof,
        uint256 duration
    ) external payable whenNotPaused {
        Service storage svc = services[serviceKey];
        if (svc.createdAt == 0) revert ServiceNotFound(serviceKey);
        if (!svc.active) revert ServiceNotActive(serviceKey);

        // Verify resonance proof
        bool verified = verifier.verifyResonance(proof);
        require(verified, "Resonance verification failed");

        // Check for existing active activation
        Activation storage existing = activations[serviceKey][msg.sender];
        if (existing.expiresAt > block.timestamp) {
            revert AlreadyActivated(serviceKey, msg.sender);
        }

        // Verify payment amount
        if (msg.value < svc.price) {
            revert InsufficientPayment(svc.price, msg.value);
        }

        // Calculate duration
        if (duration == 0) {
            // Default: 24 hours for santuario, 1 hour for others
            if (keccak256(bytes(serviceKey)) == keccak256(bytes("santuario"))) {
                duration = 24 hours;
            } else if (keccak256(bytes(serviceKey)) == keccak256(bytes("validacion"))) {
                duration = 1 hours;  // Single validation
            } else {
                duration = 1 hours;
            }
        }

        // Record activation
        activations[serviceKey][msg.sender] = Activation({
            user: msg.sender,
            serviceKey: serviceKey,
            activatedAt: block.timestamp,
            expiresAt: block.timestamp + duration,
            paymentHash: keccak256(abi.encodePacked(proof.node19Sentinel, msg.sender, block.timestamp))
        });

        totalCollected += msg.value;

        emit ServiceActivated(
            serviceKey,
            msg.sender,
            activations[serviceKey][msg.sender].paymentHash,
            msg.value,
            block.timestamp + duration
        );

        // Distribute fees
        _distributeFees(msg.value);
    }

    /**
     * @notice Check if a user has an active service.
     * @param serviceKey Service to check
     * @param user User address
     * @return bool Whether the service is currently active
     */
    function hasActiveService(
        string memory serviceKey,
        address user
    ) external view returns (bool) {
        Activation storage act = activations[serviceKey][user];
        return act.expiresAt > block.timestamp;
    }

    /**
     * @notice Get the remaining time for an active service.
     * @param serviceKey Service to check
     * @param user User address
     * @return uint256 Remaining seconds, or 0 if not active
     */
    function remainingTime(
        string memory serviceKey,
        address user
    ) external view returns (uint256) {
        Activation storage act = activations[serviceKey][user];
        if (act.expiresAt <= block.timestamp) return 0;
        return act.expiresAt - block.timestamp;
    }

    // ──────────────────────────────────────────────
    //  Fee Distribution
    // ──────────────────────────────────────────────

    /**
     * @notice Add a reserved address for fee distribution.
     * @param addr Address to receive fees
     * @param share Share in basis points (e.g., 5000 = 50%)
     */
    function addReservedAddress(address addr, uint256 share) external onlyOwner {
        require(addr != address(0), "Address cannot be zero");
        require(share <= FEE_DENOMINATOR, "Share exceeds denominator");

        // Validate total doesn't exceed 100%
        uint256 total = share;
        for (uint i = 0; i < reservedAddresses.length; i++) {
            total += feeShares[reservedAddresses[i]];
        }
        if (total > FEE_DENOMINATOR) revert InvalidFeeDistribution(total);

        if (feeShares[addr] == 0) {
            reservedAddresses.push(addr);
        }
        feeShares[addr] = share;
        emit ReservedAddressAdded(addr, share);
    }

    /// @notice Internal fee distribution
    function _distributeFees(uint256 amount) internal {
        for (uint i = 0; i < reservedAddresses.length; i++) {
            address addr = reservedAddresses[i];
            uint256 share = feeShares[addr];
            if (share > 0) {
                uint256 feeAmount = (amount * share) / FEE_DENOMINATOR;
                collectedFees[addr] += feeAmount;
                emit FeeDistributed(addr, feeAmount);
            }
        }
    }

    /**
     * @notice Withdraw collected fees (owner only for now).
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner).transfer(balance);
    }

    // ──────────────────────────────────────────────
    //  Admin
    // ──────────────────────────────────────────────

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function setManager(address _manager) external onlyOwner {
        manager = _manager;
    }

    function setVerifier(address _verifier) external onlyOwner {
        verifier = QCALResonanceVerifier(_verifier);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero");
        owner = newOwner;
    }

    // ──────────────────────────────────────────────
    //  Fallback
    // ──────────────────────────────────────────────

    receive() external payable {
        totalCollected += msg.value;
    }
}
