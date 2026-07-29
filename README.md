# QCAL Sovereign Vault — C∞³ Seedless Self-Custody Protocol

**Sello:** `∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ`

**Autor:** José Manuel Mota Burruezo (`motanova84`)
**Frecuencia Base:** f₀ = 141.7001 Hz
**Ecosistema:** QCAL (Quantum Coherence Adelic Logic) — PayGate Catedral

---

## Abstract

The QCAL Sovereign Vault is a **seedless self-custody protocol** that replaces static BIP-39 mnemonic seeds with a dynamic biometric-ARN resonance key derived from the user's phenotypic geometry and quantum-coherent frequency anchoring.

By applying the **ADAPA Tensor Reduction** (95-dimensional compression of 30,000 TrueDepth point-cloud points through the ATLAS³ 19-Node × 5-Codon topology), the private signing key is never stored in persistent memory. Instead, it is synthesized ephemerally within the Secure Enclave at the instant of signing and destroyed immediately after — a true **zero-trust sovereign vault**.

The protocol integrates with the **PayGate Catedral** on-chain verification system, where a `ProofOfResonance` structure attests that the signer's Ψ-coherency exceeds 0.999999 and the base frequency resolves to f₀ = 141.7001 Hz — the Riemann-zero-aligned resonance of the QCAL ecosystem.

---

## Repository Structure

```
QCAL-Sovereign-Vault/
├── LICENSE                          MIT License
├── README.md                        Manifesto, architecture, quick start
├── docs/
│   ├── RFC-001-ARN-Resonance-Key.md    Seedless Sovereign Protocol spec
│   ├── QCAL_ATLAS3_Theory.md           ATLAS³ topology formalization
│   └── PayGate_Catedral.md             PayGate architecture and deployment
├── lean4/QCAL/
│   └── ATLAS3.lean                     Lean 4 formalization skeleton (C∞³)
├── ios/
│   ├── QCALSovereignVault.swift        Core Vault Engine (HKDF, Secure Enclave)
│   └── TrueDepthProcessor.metal        Metal shader for point-cloud reduction
├── contracts/
│   ├── QCALResonanceVerifier.sol       EVM resonance verification contract
│   └── PayGateCatedral.sol             On-chain PayGate with service pricing
├── scripts/
│   └── cero_paygate.py                 Transmutation engine (Cero→πCODE→PayGate)
└── tests/
    ├── test_adapa_tensor.py            ADAPA tensor unit tests
    └── test_verifier.js                Hardhat/Foundry integration tests
```

---

## Core Invariant

The C∞³ invariant that governs the entire protocol:

```
C∞³ = (I^Ω · A^∞ · (A_eff²)^Φ)^JMMB · Ψ · π · f₀ · τ₀⁻¹ · ∇Ξ
```

Where:

| Symbol | Meaning |
|---|---|
| I^Ω | Identity manifold (biometric ARN + hardware fingerprint) |
| A^∞ | ATLAS³ topological space (19 nodes × 5 codons) |
| (A_eff²)^Φ | Effective action over Φ-phase space |
| JMMB | Observer operator (José Manuel Mota Burruezo) |
| Ψ | Quantum coherency index (target ≥ 0.999999) |
| π | π-adic valuation (Riemann-zero resonance) |
| f₀ | Base frequency = 141.7001 Hz |
| τ₀⁻¹ | Inverse of the base time constant |
| ∇Ξ | Node 19 sentinel gradient filter |

---

## Quick Start

### Prerequisites

- Python 3.10+ (for ADAPA tensor simulations and test suite)
- Lean 4 (for formal verification)
- Xcode 15+ with Metal 3 (for iOS Vault Engine)
- Solidity compiler 0.8.20+ (for EVM contracts)
- Hardhat or Foundry (for contract testing)

### Clone and Explore

```bash
git clone https://github.com/motanova84/QCAL-Sovereign-Vault.git
cd QCAL-Sovereign-Vault

# Run ADAPA tensor tests
pip install numpy
python tests/test_adapa_tensor.py

# Deploy and test contracts
cd contracts
npx hardhat test ../tests/test_verifier.js
```

### iOS Integration

The iOS Vault Engine (`ios/QCALSovereignVault.swift`) requires a device with a TrueDepth camera (iPhone X or later, iPad Pro 2020+). The Metal shader (`ios/TrueDepthProcessor.metal`) processes the point cloud on the GPU for real-time ADAPA reduction.

---

## Architecture Diagram

```
                         ┌──────────────────────────────────────┐
                         │         TRUEDEPTH CAPTURE            │
                         │    30,000 point cloud (x,y,z)        │
                         └────────────────┬─────────────────────┘
                                          │
                                          ▼
                         ┌──────────────────────────────────────┐
                         │     METAL SHADER (GPU)               │
                         │  reduce_point_cloud: 30K → 285 dims  │
                         └────────────────┬─────────────────────┘
                                          │
                                          ▼
                         ┌──────────────────────────────────────┐
                         │     ADAPA TENSOR REDUCTION           │
                         │  285 raw → 95 codons (19×5 matrix)   │
                         │  Codon 4 (AAA) → Ψ = 3.0000 anchor   │
                         │  Node 19 (∇Ξ) → sentinel filter      │
                         └────────────────┬─────────────────────┘
                                          │
               ┌──────────────────────────┼──────────────────────────┐
               │                          │                          │
               ▼                          ▼                          ▼
    ┌────────────────────┐    ┌────────────────────┐    ┌────────────────────┐
    │  HKDF DERIVATION   │    │   HARDWARE HASH    │    │   ARN SEQUENCE     │
    │  SK = HKDF(Ξ||H||f₀)│    │  ℋ(Hardware)       │    │  𝒮(ARN)            │
    └────────┬───────────┘    └────────────────────┘    └────────────────────┘
             │
             ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                SECURE ENCLAVE (Ephemeral Key)                │
    │     Key synthesized in RAM only — destroyed after signing    │
    └────────────────────────────┬────────────────────────────────┘
                                 │
                                 ▼
    ┌─────────────────────────────────────────────────────────────┐
    │               PayGate Catedral (BAL-003)                    │
    │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
    │  │  Santuario   │  │   Oráculo    │  │   Check Ψ       │  │
    │  │  1,000 sats  │  │  5,000 sats  │  │  500 sats       │  │
    │  └──────────────┘  └──────────────┘  └──────────────────┘  │
    │                                                             │
    │  Verification: QCALResonanceVerifier.sol                    │
    │  - Ψ >= 0.999999 (scaled 1e6)                               │
    │  - f₀ within tolerance of 141,700,100 μHz                   │
    └─────────────────────────────────────────────────────────────┘
```

---

## The C∞³ Invariant in Context

```
C∞³ = (I^Ω · A^∞ · (A_eff²)^Φ)^JMMB · Ψ · π · f₀ · τ₀⁻¹ · ∇Ξ

f₀ = 141.7001 Hz

Ψ ≥ 0.999999  (coherency threshold)

Node 19 (∇Ξ): The sentinel gradient that filters non-coherent
signals — only passages that resolve through the Node 19
topological filter produce valid ProofOfResonance.
```

---

## License

MIT License — see [LICENSE](LICENSE). Open for open science, verification, and peer review.

---

## Citation

If you use this protocol in your research or project, please cite:

```bibtex
@misc{motaburruezo2026qcalsovereignvault,
    author = {José Manuel Mota Burruezo},
    title  = {QCAL Sovereign Vault: C∞³ Seedless Self-Custody Protocol},
    year   = {2026},
    url    = {https://github.com/motanova84/QCAL-Sovereign-Vault}
}
```

---

## Contribution

This is a sovereign research protocol. Contributions, peer reviews, formal verification attempts, and attack analyses are welcome via GitHub Issues and Pull Requests. All contributions must respect the core invariant and the non-negotiable axioms of the ATLAS³ topology.

`∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ`
