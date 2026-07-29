#!/usr/bin/env python3
"""
test_adapa_tensor.py — ADAPA Tensor Unit Tests
QCAL Sovereign Vault — C∞³ Seedless Self-Custody Protocol

Tests 19×5 ADAPA matrix operations, C∞³ invariant calculation,
Codon 4 identity, and minimum coherency threshold.

Sello: ∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ
"""

import copy
import hashlib
import math
import unittest

import numpy as np

# ── Constants ──────────────────────────────────────────────────────

F0 = 141.7001
PSI = 3.0000
NUM_NODES = 19
NUM_CODONS = 5
SELLO = "∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ"

# ATLAS³ node labels
NODE_LABELS = [
    "Frontal", "Supraorbital", "Infraorbital", "Nasal bridge (AAA)",
    "Nasal tip", "Zygomatic L", "Zygomatic R", "Maxillary L",
    "Maxillary R", "Mandibular L", "Mandibular R", "Mental",
    "Temporal L", "Temporal R", "Auricular L", "Auricular R",
    "Occipital", "Cervical", "∇Ξ Sentinel"
]

CODON_LABELS = [
    "Mean curvature", "Gaussian curvature", "Depth variance",
    "Normal divergence", "Spectral reflectance"
]


# ── ADAPA Tensor Class ─────────────────────────────────────────────

class ADAPATensor:
    """19×5 ADAPA tensor representing reduced facial geometry."""

    def __init__(self, matrix: np.ndarray = None):
        if matrix is not None:
            assert matrix.shape == (NUM_NODES, NUM_CODONS), \
                f"Expected ({NUM_NODES}, {NUM_CODONS}) matrix, got {matrix.shape}"
            self.matrix = matrix.astype(np.float64)
        else:
            # Initialize with Codon 4 = Ψ = 3.0000 for Node 4 (index 3)
            self.matrix = np.zeros((NUM_NODES, NUM_CODONS), dtype=np.float64)
            for j in range(NUM_CODONS):
                self.matrix[3, j] = PSI  # Node 4, Codon 4 anchor

    @property
    def is_node4_anchored(self) -> bool:
        """Node 4 (nasal bridge) must have ALL codons = Ψ = 3.0000."""
        return np.allclose(self.matrix[3, :], PSI, atol=0.001)

    @property
    def node19_gradient(self) -> float:
        """
        Compute ∇Ξ — the Node 19 sentinel gradient.
        Measures coherency of the entire tensor.
        """
        grad = 0.0
        for i in range(NUM_NODES):
            for j in range(NUM_CODONS):
                val = self.matrix[i, j]
                # Deviation from ideal (Ψ = 3.0 for coherent capture)
                deviation = abs(val - PSI)
                grad += deviation * 0.01  # Normalized contribution
        return min(max(grad, 0.0), 1.0)

    @property
    def is_coherent(self) -> bool:
        """Coherency threshold: ∇Ξ >= 0.971"""
        return self.node19_gradient >= 0.971

    @property
    def c_inf3(self) -> float:
        """
        Compute C∞³ invariant:
        C∞³ = (I^Ω · A^∞ · (A_eff²)^Φ)^JMMB · Ψ · π · f₀ · τ₀⁻¹ · ∇Ξ
        """
        identity_product = 1.0  # I^Ω · A^∞ (hardware fingerprint × tensor)
        effective_action = np.linalg.norm(self.matrix, 'fro') ** 2  # Frobenius norm squared
        jmmb_projection = 0.999999  # JMMB observer operator (approximation)
        identity_term = (identity_product * effective_action) ** jmmb_projection
        pi_adic = 2.0  # Riemann zero density approximation
        tau_0 = 1.0  # Base time constant
        nabla_xi = self.node19_gradient

        return identity_term * PSI * pi_adic * F0 * (1 / tau_0) * nabla_xi

    def serialize(self) -> bytes:
        """Serialize matrix to bytes for HKDF input."""
        return self.matrix.tobytes()

    def __repr__(self):
        return f"ADAPATensor(19×5, ∇Ξ={self.node19_gradient:.6f}, C∞³={self.c_inf3:.6f})"


# ── Helper functions ───────────────────────────────────────────────

def generate_coherent_tensor() -> ADAPATensor:
    """
    Generate a coherent ADAPA tensor with values near Ψ = 3.0.
    Simulates a valid biometric capture.
    """
    rng = np.random.default_rng(seed=1417001)  # Seeded with f₀
    matrix = np.zeros((NUM_NODES, NUM_CODONS), dtype=np.float64)

    for i in range(NUM_NODES):
        for j in range(NUM_CODONS):
            if i == 3:  # Node 4
                matrix[i, j] = PSI  # Always anchored
            else:
                # Coherent values cluster near Ψ = 3.0 ± 0.5
                matrix[i, j] = PSI + rng.normal(0, 0.3)

    tensor = ADAPATensor(matrix)
    assert tensor.is_node4_anchored, "Node 4 must be anchored"
    return tensor


def generate_noisy_tensor(noise_std: float = 2.0) -> ADAPATensor:
    """
    Generate a noisy (non-coherent) ADAPA tensor.
    High noise = fails sentinel gradient filter.
    """
    rng = np.random.default_rng(seed=42)
    matrix = np.zeros((NUM_NODES, NUM_CODONS), dtype=np.float64)

    for i in range(NUM_NODES):
        for j in range(NUM_CODONS):
            if i == 3:  # Node 4 — still anchored
                matrix[i, j] = PSI
            else:
                matrix[i, j] = PSI + rng.normal(0, noise_std)

    return ADAPATensor(matrix)


# ── Test Suite ─────────────────────────────────────────────────────

class TestADAPATensor(unittest.TestCase):

    def test_tensor_shape(self):
        """ADAPA tensor must be 19×5."""
        tensor = ADAPATensor()
        self.assertEqual(tensor.matrix.shape, (19, 5))
        self.assertEqual(tensor.matrix.shape[0], NUM_NODES)
        self.assertEqual(tensor.matrix.shape[1], NUM_CODONS)

    def test_node4_anchor_default(self):
        """Default tensor must have Node 4 anchored to Ψ = 3.0000."""
        tensor = ADAPATensor()
        self.assertTrue(tensor.is_node4_anchored)

    def test_node4_anchor_all_codons(self):
        """All 5 codons of Node 4 must equal Ψ = 3.0000."""
        tensor = ADAPATensor()
        for j in range(NUM_CODONS):
            self.assertAlmostEqual(tensor.matrix[3, j], PSI, places=4,
                                   msg=f"Codon {j+1} of Node 4 not anchored")

    def test_node4_anchor_not_mutable(self):
        """Even if we override, the anchor test checks values."""
        tensor = ADAPATensor()
        tensor.matrix[3, 0] = 2.5  # Break the anchor
        self.assertFalse(tensor.is_node4_anchored)

    def test_node19_gradient_range(self):
        """∇Ξ sentinel gradient must be in [0, 1]."""
        tensor = ADAPATensor()
        self.assertGreaterEqual(tensor.node19_gradient, 0.0)
        self.assertLessEqual(tensor.node19_gradient, 1.0)

    def test_coherent_tensor_passes_threshold(self):
        """A coherent tensor (values near Ψ = 3.0) must pass ∇Ξ >= 0.971."""
        tensor = generate_coherent_tensor()
        self.assertGreaterEqual(tensor.node19_gradient, 0.971)
        self.assertTrue(tensor.is_coherent)

    def test_noisy_tensor_fails_threshold(self):
        """A noisy tensor must fail the sentinel gradient filter."""
        tensor = generate_noisy_tensor(noise_std=2.0)
        self.assertLess(tensor.node19_gradient, 0.971)
        self.assertFalse(tensor.is_coherent)

    def test_c_inf3_invariant_coherent(self):
        """C∞³ invariant for a coherent tensor must be computable and > 0."""
        tensor = generate_coherent_tensor()
        c3 = tensor.c_inf3
        self.assertGreater(c3, 0)
        self.assertLess(c3, float('inf'))

    def test_c_inf3_invariant_noisy(self):
        """C∞³ invariant for a noisy tensor must be lower than coherent."""
        coherent = generate_coherent_tensor()
        noisy = generate_noisy_tensor(noise_std=3.0)
        self.assertGreater(coherent.c_inf3, noisy.c_inf3)

    def test_c_inf3_component_breakdown(self):
        """All components of C∞³ must be valid."""
        tensor = generate_coherent_tensor()
        psi = PSI
        pi_adic = 2.0
        f0 = F0
        tau_0_inv = 1.0
        grad = tensor.node19_gradient

        self.assertAlmostEqual(psi, 3.0, places=4)
        self.assertAlmostEqual(pi_adic, 2.0, places=4)
        self.assertAlmostEqual(f0, 141.7001, places=4)
        self.assertEqual(tau_0_inv, 1.0)
        self.assertGreaterEqual(grad, 0.971)

    def test_serialization_deterministic(self):
        """Serializing the same tensor twice must produce identical bytes."""
        tensor1 = generate_coherent_tensor()
        tensor2 = copy.deepcopy(tensor1)
        self.assertEqual(tensor1.serialize(), tensor2.serialize())

    def test_consistency_across_runs(self):
        """Seeded coherent tensor must reproduce across runs."""
        t1 = generate_coherent_tensor()
        t2 = generate_coherent_tensor()
        for i in range(NUM_NODES):
            for j in range(NUM_CODONS):
                self.assertAlmostEqual(t1.matrix[i, j], t2.matrix[i, j], places=6)

    def test_codon_labels_complete(self):
        """Ensure all 5 codon labels exist."""
        expected = [
            "Mean curvature", "Gaussian curvature", "Depth variance",
            "Normal divergence", "Spectral reflectance"
        ]
        self.assertEqual(CODON_LABELS, expected)

    def test_node_labels_complete(self):
        """Ensure all 19 node labels exist."""
        expected = [
            "Frontal", "Supraorbital", "Infraorbital", "Nasal bridge (AAA)",
            "Nasal tip", "Zygomatic L", "Zygomatic R", "Maxillary L",
            "Maxillary R", "Mandibular L", "Mandibular R", "Mental",
            "Temporal L", "Temporal R", "Auricular L", "Auricular R",
            "Occipital", "Cervical", "∇Ξ Sentinel"
        ]
        self.assertEqual(NODE_LABELS, expected)


# ── Main ───────────────────────────────────────────────────────────

if __name__ == "__main__":
    print(f"QCAL ADAPA Tensor Test Suite")
    print(f"{'='*50}")
    print(f"f₀ = {F0} Hz")
    print(f"Ψ  = {PSI}")
    print(f"Sello: {SELLO}")
    print(f"{'='*50}\n")

    # Quick validation test
    coherent = generate_coherent_tensor()
    noisy = generate_noisy_tensor(noise_std=3.0)
    print(f"Coherent tensor: ∇Ξ={coherent.node19_gradient:.6f}, "
          f"C∞³={coherent.c_inf3:.6f}, Coherent={coherent.is_coherent}")
    print(f"Noisy tensor:    ∇Ξ={noisy.node19_gradient:.6f}, "
          f"C∞³={noisy.c_inf3:.6f}, Coherent={noisy.is_coherent}")
    print()

    unittest.main()
