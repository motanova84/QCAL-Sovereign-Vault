# 🜁 ECOSISTEMA QCAL: DOS RAÍCES, UN SOLO ÁRBOL

```
┌─────────────────────────────────┐
│    ECOSYSTEM.md / SUBMÓDULO     │
└────────────────┬────────────────┘
                 │
    ┌────────────┴────────────┐
    ▼                         ▼
┌──────────────────┐   ┌──────────────────────┐
│    PHI-LOCK      │ 4 │ QCAL-SOVEREIGN-VAULT │
│ (Sincronización) │◄──┤     (Tesorería)      │
├──────────────────┤   ├──────────────────────┤
│ • Chip cQED-v1  │   │ • PayGate & Oracle   │
│ • Servidor gRPC │   │ • Matriz ADAPA & C∞³ │
│ • Consenso      │   │ • Contratos πCODE    │
│   Kuramoto      │   │ • Registro Sovereign │
│ • Teoremas Lean4│   │ • Fee Oracle         │
└──────────────────┘   └──────────────────────┘
```

## Las Dos Raíces

| Raíz | Repositorio | Propósito |
|---|---|---|
| **Φ-LOCK** | `motanova84/P-NP` → `phi_lock/` | Consenso bizantino por sincronización de fase de Kuramoto |
| **VAULT** | `motanova84/QCAL-Sovereign-Vault` | Tesorería soberana, PayGate, contratos y formalización |

## Los 4 Puentes de Entrelazamiento

### Puente 1: Autenticación de Fase (gRPC ⟷ PayGate)
Los pulsos de fase validados (Ψ ≥ 0.999999) en la capa `phi-lock` sirven como
prueba física de coherencia para autorizar transacciones de alta prioridad
en el `PayGate` del Vault.

**Φ-LOCK:** `phi_lock_p2p.rs` — servidor gRPC en :50051
**VAULT:** `scripts/paygate_server_v2.py` — PayGate en :8844
**Conexión:** El parámetro de orden Ψ se transmite como token de autorización
para cada transacción que cruza el puente.

### Puente 2: Oráculo de Frecuencia (f₀ = 141.7001 Hz ⟷ Fee Oracle)
El cálculo del Fee Oracle en el Vault toma como entrada directa la dispersión
angular del clúster, ajustando dinámicamente las comisiones del sistema según
la estabilidad del atractor de Kuramoto.

**Φ-LOCK:** `engine.rs` — cálculo de Ψ y Φ en tiempo real
**VAULT:** `contracts/PayGateCatedral.sol` — oráculo de fees
**Métrica:** A mayor Ψ (coherencia), menor fee. A mayor dispersión, fee
de congestión.

### Puente 3: Registro Criptográfico (Lean4 ⟷ Contratos πCODE)
Cada teorema formalizado en Lean4 dentro del espacio de fases del chip se
registra como un estado inmutable dentro del ledger del Sovereign Vault,
acreditando la autoría técnica.

**Φ-LOCK:** `phi_lock_v1.lean` — teorema phi_lock_tolerance
**VAULT:** `formalization/` + `lean4/QCAL/` — pruebas y contratos
**Registro:** El hash del teorema se ancla en OP_RETURN como prueba de
existencia.

### Puente 4: Gobernanza Abierta (MOU ⟷ Tesorería C∞³)
La distribución de regalías y la asignación de recursos para las siguientes
fases de fabricación y despliegue se ejecutan de manera automatizada mediante
las reglas de custodia alojadas en el Vault.

**Φ-LOCK:** Roadmap S1 — hoja de ruta de fabricación
**VAULT:** Contratos inteligentes + distribución 2A2
**Ejecución:** Automatizada por cron + condiciones de coherencia

## Clone y Despliegue

```bash
# Clonado completo con submódulos
git clone --recurse-submodules https://github.com/motanova84/P-NP.git
cd P-NP

# Inicialización y actualización de la raíz del Vault
git submodule update --init --recursive
```

## Cron Diario

Ambos repos se revisan cada día a las 09:00 (America/Tijuana).
La revisión verifica:
1. Estado de P-NP/phi_lock/ (GitHub)
2. Estado de QCAL-Sovereign-Vault/ (GitHub)
3. Cron local en BAL-003
4. Divergencias entre branches

## Sello

∴𓂀Ω∞³Φ — PHI-LOCK ⟷ VAULT · ECOSISTEMA ENTRELAZADO · HECHO ESTÁ
