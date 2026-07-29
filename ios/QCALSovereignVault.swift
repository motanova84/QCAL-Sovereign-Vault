//
//  QCALSovereignVault.swift
//  QCAL Sovereign Vault — C∞³ Seedless Self-Custody Protocol
//
//  Sello: ∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ
//  f₀ = 141.7001 Hz
//
//  Core Vault Engine for iOS: HKDF derivation, ADAPA tensor reduction,
//  and ephemeral key synthesis using TrueDepth + Secure Enclave.
//

import Foundation
import CryptoKit
import LocalAuthentication
import simd

// MARK: - Constants

let QCALF0: Double = 141.7001
let QCALSello: String = "∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ"
let QCALCoherencyThreshold: Double = 0.999999
let QCALSentinelThreshold: Double = 0.971
let QCALProtocolVersion: String = "QCAL-Sovereign-Vault/v1"

// MARK: - ADAPA Tensor (19×5 Matrix)

/// Represents the ADAPA-reduced 95-dimensional tensor
/// from 19 ATLAS³ nodes × 5 codons each.
struct ADAPATensor95D: Codable, Equatable {
    /// 19 rows (nodes) × 5 columns (codons)
    var matrix: [[Double]]  // shape: [19][5]

    /// Codon 4 (AAA) identity anchor: Ψ = 3.0000
    static let codon4Anchor: Double = 3.0000

    init() {
        // Initialize with Codon 4 = Ψ for all nodes
        self.matrix = Array(repeating: Array(repeating: 0.0, count: 5), count: 19)
        // Node 4 (index 3) is the AAA anchor — all 5 codons = Ψ
        for j in 0..<5 {
            matrix[3][j] = Self.codon4Anchor
        }
    }

    /// Check that Node 4 (nasal bridge) is anchored to Ψ
    var isNode4Anchored: Bool {
        guard matrix.count == 19 else { return false }
        for j in 0..<5 {
            guard matrix[3].count == 5 else { return false }
            if abs(matrix[3][j] - Self.codon4Anchor) > 0.001 { return false }
        }
        return true
    }

    /// Compute the Node 19 sentinel gradient ∇Ξ
    var node19Gradient: Double {
        // ∇Ξ = Σᵢ (∂Ξ_i / ∂x · ∇²Ξ_i)
        // Simplified: compute the sum of absolute differences across the matrix
        var grad: Double = 0.0
        for i in 0..<19 {
            for j in 0..<5 {
                if i > 0 {
                    grad += abs(matrix[i][j] - matrix[i-1][j]) * 0.01
                }
            }
        }
        return min(max(grad, 0.0), 1.0)
    }

    /// Check that the sentinel gradient exceeds the coherence threshold
    var isCoherent: Bool {
        return node19Gradient >= QCALSentinelThreshold
    }

    /// Serialize matrix to flat Data for HKDF input
    func serialized() -> Data {
        var data = Data()
        for row in matrix {
            for val in row {
                withUnsafeBytes(of: val) { data.append(contentsOf: $0) }
            }
        }
        return data
    }
}

// MARK: - ARN Resonance Key

/// Represents a key derived from biometric-ARN resonance.
struct ARNResonanceKey: Codable {
    let version: String
    let timestamp: Date
    let keyMaterial: Data  // 32 bytes of derived key material
    let sentinel: String   // Node 19 sentinel hash (first 16 hex chars)
    let nonce: Data        // 16-byte fresh nonce

    /// Generate a resonance key from hardware data + ARN data + frequency
    static func synthesizeKey(
        hardwareData: Data,
        arnData: Data,
        frequency: Double = QCALF0,
        adapaTensor: ADAPATensor95D
    ) throws -> ARNResonanceKey {
        guard adapaTensor.isNode4Anchored else {
            throw QCALError.node4NotAnchored
        }

        guard adapaTensor.isCoherent else {
            throw QCALError.coherencyBelowThreshold(sentinel: adapaTensor.node19Gradient)
        }

        // Generate fresh nonce
        var nonce = Data(count: 16)
        let result = nonce.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, 16, ptr.baseAddress!)
        }
        guard result == errSecSuccess else {
            throw QCALError.randomGenerationFailed
        }

        // Build HKDF salt = ARN data || nonce
        let salt = arnData + nonce

        // Build IKM = hardware fingerprint || ADAPA tensor (serialized)
        let ikm = hardwareData + adapaTensor.serialized()

        // Build info string = protocol version || frequency || sentinel
        let freqStr = String(format: "%.4f", frequency)
        let sentinelHex = adapaTensor.node19Gradient.toHexString(length: 8)
        let info = "\(QCALProtocolVersion):\(freqStr):\(sentinelHex)".data(using: .utf8)!

        // Derive key using HKDF-SHA512
        let symmetricKey = HKDF<SHA512>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: ikm),
            salt: salt,
            info: info,
            outputByteCount: 32
        )

        let keyData = symmetricKey.withUnsafeBytes { Data($0) }

        return ARNResonanceKey(
            version: QCALProtocolVersion,
            timestamp: Date(),
            keyMaterial: keyData,
            sentinel: sentinelHex,
            nonce: nonce
        )
    }

    /// Zero out key material (destruction)
    mutating func destroy() {
        keyMaterial.withUnsafeMutableBytes { ptr in
            memset(ptr.baseAddress!, 0, ptr.count)
        }
    }
}

// MARK: - Codon4 Enum

/// Specialized enum for the AAA Codon 4 identity anchor.
/// Ψ = 3.0000 for all Codon 4 positions.
enum Codon4: Double, Codable {
    case psi = 3.0000

    var description: String {
        switch self {
        case .psi: return "AAA (Identity Anchor, Ψ = 3.0000)"
        }
    }

    /// Check if a given value matches the Codon 4 anchor
    static func matches(_ value: Double, tolerance: Double = 0.001) -> Bool {
        return abs(value - Codon4.psi.rawValue) <= tolerance
    }
}

// MARK: - Errors

enum QCALError: Error, LocalizedError {
    case node4NotAnchored
    case coherencyBelowThreshold(sentinel: Double)
    case randomGenerationFailed
    case trueDepthDataUnavailable
    case hardwareFingerprintUnavailable
    case keyDestructionFailed

    var errorDescription: String? {
        switch self {
        case .node4NotAnchored:
            return "Node 4 Codon 4 (AAA) no está anclado a Ψ = 3.0000"
        case .coherencyBelowThreshold(let sentinel):
            return "∇Ξ = \(sentinel) por debajo del umbral \(QCALSentinelThreshold)"
        case .randomGenerationFailed:
            return "Fallo al generar nonce criptográfico"
        case .trueDepthDataUnavailable:
            return "Datos TrueDepth no disponibles"
        case .hardwareFingerprintUnavailable:
            return "Huella de hardware no disponible"
        case .keyDestructionFailed:
            return "Fallo al destruir material de clave"
        }
    }
}

// MARK: - Hardware Fingerprint

/// Collects hardware-level identifiers for the I^Ω component.
struct HardwareFingerprintCollector {
    /// Generate a SHA-256 hash of the device's hardware identifiers.
    /// Combines: device model, UID, Secure Enclave presence, etc.
    static func collect() -> Data? {
        // In a real implementation, this would use:
        // - UIDevice.current.identifierForVendor
        // - Device model identifier
        // - Secure Enclave attestation key
        // - Biometric sensor calibration data

        var components = [String]()

        #if targetEnvironment(simulator)
        components.append("SIMULATOR")
        #else
        components.append(UIDevice.current.model)
        components.append(UIDevice.current.systemVersion)
        #endif

        components.append(QCALProtocolVersion)
        components.append(UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN")

        let combined = components.joined(separator: "|")
        guard let data = combined.data(using: .utf8) else { return nil }

        let hash = SHA256.hash(data: data)
        return Data(hash)
    }
}

// MARK: - TrueDepth Point Cloud Stub

/// Stub for TrueDepth point cloud processing.
/// In production, this receives ARFrame.anchors from ARKit.
struct TrueDepthPointCloud {
    var points: [simd_float3]  // Up to 30,000 points

    /// Reduce 30,000 points to ADAPA 95D tensor via Metal
    func reduceToADAPA() -> ADAPATensor95D {
        // In production, this dispatches to TrueDepthProcessor.metal
        // which runs the GPU kernel reduce_point_cloud
        //
        // For now, returns a minimal stub tensor.
        var tensor = ADAPATensor95D()
        // Populate with sample data derived from point cloud centroids
        // ...
        return tensor
    }
}

// MARK: - Double Extensions

private extension Double {
    /// Convert Double to hex string of given nibble length
    func toHexString(length: Int) -> String {
        let data = withUnsafeBytes(of: self) { Data($0) }
        return data.prefix(length).map { String(format: "%02x", $0) }.joined()
    }
}
