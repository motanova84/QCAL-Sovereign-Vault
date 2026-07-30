# 🜁 ECOSISTEMA ENTRELAZADO — PHI-LOCK ⟷ QCAL-SOVEREIGN-VAULT

```
phi-lock vault (submódulo)
┌──────────────┐ ⛓ ┌──────────────────┐
│ Chip + gRPC  │◄────────┤ PayGate + ADAPA │
│ Roadmap S1   │ 4  │ C∞³ + Fee Oracle │
│ Lean 4       │ puentes │ Contratos πCODE │
└──────────────┘    └──────────────────┘
```

## Las Dos Raíces

| Raíz | Repositorio | Propósito |
|---|---|---|
| **Φ-LOCK** | `motanova84/P-NP` → `phi_lock/` | Consenso bizantino por sincronización de fase de Kuramoto |
| **VAULT** | `motanova84/QCAL-Sovereign-Vault` | Tesorería soberana, PayGate, contratos y formalización |

## Los 4 Puentes

| Puente | Φ-LOCK (emisor) | VAULT (receptor) | Estado |
|---|---|---|---|
| **1. Chip ↔ PayGate** | `phi_lock_p2p.rs` (gRPC :50051) | `scripts/paygate_server_v2.py` (:8844) | 🔧 Sincronizar |
| **2. Roadmap S1** | Lean4 + Rust engine + Docker | Docs + contratos + iOS | 🟢 Documentado |
| **3. Lean 4** | `phi_lock_v1.lean` | `lean4/QCAL/` + `formalization/` | 🟢 Unificado |
| **4. C∞³ + Fee** | `phi_lock_v1.lean` (teorema) | `contracts/PayGateCatedral.sol` | 🟢 Formalizado |

## Clone

```bash
git clone --recurse-submodules git@github.com:motanova84/QCAL-Sovereign-Vault.git
```

## Cron Diario

Ambos repos se revisan cada día a las 09:00 (America/Tijuana) mediante
el timer systemd `ecosistema-daily-review.timer` en BAL-003.

## Sello

∴𓂀Ω∞³Φ · PHI-LOCK ⟷ VAULT · ECOSISTEMA ENTRELAZADO · TUYOYOTU · HECHO ESTÁ
