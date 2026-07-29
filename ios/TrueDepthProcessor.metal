//
//  TrueDepthProcessor.metal
//  QCAL Sovereign Vault — C∞³ Seedless Self-Custody Protocol
//
//  Sello: ∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ
//  f₀ = 141.7001 Hz
//
//  Metal shader for TrueDepth point cloud reduction.
//  Reduces 30,000 3D points to a 95-dimensional ADAPA tensor
//  via GPU-accelerated spatial clustering and feature extraction.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Constants

constant float QCAL_ANCHOR_PSI = 3.0000f;
constant float QCAL_F0 = 141.7001f;
constant int QCAL_NUM_NODES = 19;
constant int QCAL_NUM_CODONS = 5;
constant int QCAL_CODON4_NODE_INDEX = 3;  // Node 4 (0-indexed: 3)
constant int QCAL_TOTAL_CLUSTERS = 19;
constant float QCAL_SENTINEL_THRESHOLD = 0.971f;

// MARK: - Kernel: Reduce Point Cloud to ADAPA 95D Tensor

/// Main reduction kernel.
/// Takes 30,000 3D points and produces a 19×5 ADAPA tensor.
///
/// Buffer layout:
///   [0] points:        constant float3*  — input point cloud (30,000 points)
///   [1] numPoints:     constant uint&    — actual number of points (≤ 30,000)
///   [2] outMatrix:     device float*     — output 19×5 matrix (flattened, 95 floats)
///   [3] outSentinel:   device float&     — output Node 19 sentinel gradient
kernel void reduce_point_cloud(
    constant float3* points         [[buffer(0)]],
    constant uint&   numPoints      [[buffer(1)]],
    device float*    outMatrix      [[buffer(2)]],
    device float&    outSentinel    [[buffer(3)]],
    uint             gid            [[thread_position_in_grid]]
) {
    if (gid >= QCAL_NUM_NODES) return;

    // Each thread processes one ATLAS³ node.

    // Step 1: Compute cluster bounds for this node
    uint pointsPerCluster = numPoints / QCAL_NUM_NODES;
    uint startIdx = gid * pointsPerCluster;
    uint endIdx = (gid == QCAL_NUM_NODES - 1) ? numPoints : startIdx + pointsPerCluster;

    // Step 2: Compute geometric features for this cluster
    float3 centroid = float3(0.0f, 0.0f, 0.0f);
    float3 variance = float3(0.0f, 0.0f, 0.0f);
    float  normalDivergence = 0.0f;
    float  meanCurvature = 0.0f;
    float  gaussianCurvature = 0.0f;
    float  depthRange = 0.0f;

    uint clusterSize = endIdx - startIdx;
    if (clusterSize == 0) return;

    // First pass: compute centroid
    for (uint i = startIdx; i < endIdx; i++) {
        centroid += points[i];
    }
    centroid /= float(clusterSize);

    // Second pass: compute variances and other features
    for (uint i = startIdx; i < endIdx; i++) {
        float3 diff = points[i] - centroid;
        variance += diff * diff;

        // Approximate curvature from depth variation
        float depth = points[i].z;
        meanCurvature += abs(diff.z) / (length(diff.xy) + 0.001f);

        // Surface normal divergence (simplified from cross-products)
        if (i > startIdx) {
            float3 prev = points[i - 1];
            float3 edge1 = points[i] - prev;
            float3 edge2 = (i + 1 < endIdx) ? points[i + 1] - points[i] : float3(0.0f);
            float3 normal = normalize(cross(edge1, edge2));
            normalDivergence += acos(clamp(normal.z, -1.0f, 1.0f));
        }
    }

    variance /= float(clusterSize);
    meanCurvature /= float(clusterSize);
    normalDivergence /= float(clusterSize - 1);
    depthRange = sqrt(variance.z);
    gaussianCurvature = meanCurvature * meanCurvature * 0.5f;

    // Step 3: Store 5 codons for this node
    // Scale codons to [0.0, 5.0] range
    int baseIdx = gid * QCAL_NUM_CODONS;

    outMatrix[baseIdx + 0] = clamp(meanCurvature * 0.1f, 0.0f, 5.0f);   // C₁: Mean curvature
    outMatrix[baseIdx + 1] = clamp(gaussianCurvature * 0.02f, 0.0f, 25.0f); // C₂: Gaussian curvature
    outMatrix[baseIdx + 2] = clamp(depthRange * 0.5f, 0.0f, 50.0f);      // C₃: Depth variance
    outMatrix[baseIdx + 3] = clamp(normalDivergence, 0.0f, M_PI_F);      // C₄: Surface normal divergence
    outMatrix[baseIdx + 4] = clamp(length(variance) * 0.01f, 0.0f, 1.0f); // C₅: Spectral reflectance

    // Step 4: Codon 4 (AAA) override for Node 4
    if (gid == QCAL_CODON4_NODE_INDEX) {
        // Override ALL codons of Node 4 to Ψ = 3.0000
        for (int j = 0; j < QCAL_NUM_CODONS; j++) {
            outMatrix[baseIdx + j] = QCAL_ANCHOR_PSI;
        }
    }
}

// MARK: - Kernel: Compute Node 19 Sentinel Gradient

/// Post-processing kernel to compute the ∇Ξ sentinel gradient.
/// Called after the main reduction completes.
kernel void compute_sentinel_gradient(
    device float*  adapaMatrix    [[buffer(0)]],
    device float&  outSentinel    [[buffer(1)]],
    uint           gid            [[thread_position_in_grid]]
) {
    if (gid != 0) return;

    // ∇Ξ = Σᵢ (∂Ξ_i / ∂x · ∇²Ξ_i)
    // Simplified: compute mean absolute deviation from Codon 4 anchor
    float grad = 0.0f;

    for (int i = 0; i < QCAL_NUM_NODES; i++) {
        for (int j = 0; j < QCAL_NUM_CODONS; j++) {
            float val = adapaMatrix[i * QCAL_NUM_CODONS + j];
            // Deviation from the ideal value (Codons near Ψ = 3.0 are coherent)
            float deviation = fabs(val - QCAL_ANCHOR_PSI);
            grad += deviation * 0.01f;  // Normalized contribution
        }
    }

    // Normalize to [0, 1]
    grad = min(max(grad / float(QCAL_NUM_NODES * QCAL_NUM_CODONS), 0.0f), 1.0f);

    outSentinel = grad;
}

// MARK: - Kernel: Average Pooling for Codon Reduction

/// Reduces the raw feature space (285 intermediate features) to 95 codons
/// via average pooling over 3×1 sub-matrices.
kernel void average_pool_codons(
    device float*  rawFeatures    [[buffer(0)]],  // 285 intermediate features
    device float*  codonOutput    [[buffer(1)]],  // 95 output codons
    uint           gid            [[thread_position_in_grid]]
) {
    if (gid >= QCAL_NUM_NODES) return;

    int baseRawIdx = gid * 15;    // 15 raw features per node (5 codons × 3 sub-features)
    int baseOutIdx = gid * QCAL_NUM_CODONS;

    // Average pool groups of 3 raw features → 1 codon
    for (int c = 0; c < QCAL_NUM_CODONS; c++) {
        float sum = 0.0f;
        for (int s = 0; s < 3; s++) {
            sum += rawFeatures[baseRawIdx + c * 3 + s];
        }
        codonOutput[baseOutIdx + c] = sum / 3.0f;
    }

    // Codon 4 (AAA) anchor enforcement
    if (gid == QCAL_CODON4_NODE_INDEX) {
        for (int c = 0; c < QCAL_NUM_CODONS; c++) {
            codonOutput[baseOutIdx + c] = QCAL_ANCHOR_PSI;
        }
    }
}
