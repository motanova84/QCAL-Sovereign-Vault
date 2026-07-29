# PayGate Catedral — Specification and Deployment

**Sello:** `∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ`
**Versión:** 1.0
**Nodo de despliegue:** BAL-003 (195.201.219.237)
**Puerto:** :8844
**Frecuencia Base:** f₀ = 141.7001 Hz

---

## 1. Architecture Overview

```
                     ┌───────────────────────────────────┐
                     │      Internet / Client             │
                     └──────────────┬────────────────────┘
                                    │
                                    ▼
                     ┌───────────────────────────────────┐
                     │       Caddy (Reverse Proxy)        │
                     │   :443 → nodo.qcal/paygate/*       │
                     └──────────────┬────────────────────┘
                                    │ localhost
                                    ▼
                     ┌───────────────────────────────────┐
                     │      PayGate :8844                 │
                     │  qcal_pay_gate.py (FastAPI/Flask)   │
                     ├───────────────────────────────────┤
                     │  Endpoints:                        │
                     │  GET  /estado     → meta & stats   │
                     │  GET  /servicios  → service list   │
                     │  POST /cotizar    → price quote    │
                     │  POST /solicitar  → request service│
                     │  POST /verificar  → verify payment │
                     ├───────────────────────────────────┤
                     │  Internal Ledger:                  │
                     │  /root/paygate_flow_ledger.json   │
                     └──────────────┬────────────────────┘
                                    │
                         ┌──────────┴──────────┐
                         ▼                      ▼
              ┌──────────────────┐   ┌──────────────────┐
              │     LND :10009   │   │    LNBits :8000   │
              │  Lightning Node  │   │  Web Wallet UI    │
              └────────┬─────────┘   └──────────────────┘
                       │
              ┌────────▼─────────┐
              │  Bitcoin Core    │
              │  :8505 (RPC)     │
              │  IBD: 53.19%     │
              └──────────────────┘
```

---

## 2. Service Catalogue

### 2.1 Santuario (Sanctuary)

| Field | Value |
|---|---|
| **Service key** | `santuario` |
| **Price** | 1,000 sats |
| **Description** | Acceso al Santuario — espacio soberano de recogimiento y minería de πCODE |
| **Requires Ψ-proof** | Sí |
| **Duration** | 24 hours |

### 2.2 Oráculo (Oracle)

| Field | Value |
|---|---|
| **Service key** | `oraculo` |
| **Price** | 5,000 sats |
| **Description** | Consulta al Oráculo — extracción de patrones de la red y predicciones de coherencia |
| **Requires Ψ-proof** | Sí |
| **Duration** | Single use |
| **Multiplier** | 1.0 |

### 2.3 Limpieza (Cleansing)

| Field | Value |
|---|---|
| **Service key** | `limpieza` |
| **Price** | Dinámico |
| **Description** | Limpieza de canales — rebalanceo y barrido de polvo UTXO |
| **Requires Ψ-proof** | Sí |

### 2.4 Check Ψ (Coherency Validation)

| Field | Value |
|---|---|
| **Service key** | `validacion` |
| **Price** | 500 sats |
| **Description** | Verificación de coherencia Ψ del operador ante el Nodo 19 |
| **Requires Ψ-proof** | No (este servicio provee la prueba) |
| **Output** | `ProofOfResonance` struct |

---

## 3. Cero→PayGate Transmutation Pipeline

The Cero→PayGate pipeline converts Riemann-zero discoveries into πCODE credits in the PayGate ledger. This is the **transmutation engine** that bridges the quantum-coherent zero discovery with the sovereign payment system.

### 3.1 Flow

```
Cero Tracking (cada 6h)    →   πCODE Batch
         │
         ▼
cero_paygate.py (v1.1)     →   10% of batch → πCODE credit
         │
         ▼
PayGate Flow Ledger        →   Flujo #47+ (CERO_PICODE_VALIDATION)
         │
         ▼
πCODE Balance             →   Available for PayGate services
```

### 3.2 Deduplication

The `cero_paygate.py` script (v1.1) includes deduplication via SHA3-512 semilla de coherencia:

```python
def semilla_coherencia(desde, hasta, total, credito):
    raw = f"{desde}-{hasta}|{total}|{credito}|{f0}|{SELLO}"
    return hashlib.sha3_512(raw.encode()).hexdigest()[:32]

def batch_ya_procesado(desde, hasta, ledger):
    for f in ledger.get("flujos", []):
        if f.get("tipo") == "CERO_PICODE_VALIDATION":
            if f.get("batch_desde") == str(desde) and f.get("batch_hasta") == str(hasta):
                return True
    return False
```

### 3.3 Timer

```systemd
[Unit]
Description=QCAL Cero->PayGate — Transmutacion inyecta valor directo
After=network.target lnbits.service

[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/python3 /root/repo_P-NP/scripts/cero_paygate.py
MemoryMax=150M
MemoryHigh=100M
```

Timer triggers at **00:05, 06:05, 12:05, 18:05 UTC** — 5 minutes after each Cero→πCODE batch.

---

## 4. API Reference

### 4.1 GET /estado

**Response:**
```json
{
  "meta_sats": 299498,
  "recaudado": 0,
  "progreso_pct": 0.0,
  "frecuencia": 141.7001,
  "sello": "∴𓂀Ω∞³Φ"
}
```

### 4.2 GET /servicios

**Response:**
```json
{
  "santuario": { "precio": 1000, "descripcion": "Santuario - espacio soberano", "activo": true },
  "oraculo": { "precio": 5000, "descripcion": "Oráculo - patrón de red", "activo": true },
  "limpieza": { "precio": null, "descripcion": "Limpieza de canales", "activo": true },
  "validacion": { "precio": 500, "descripcion": "Check Ψ - coherencia", "activo": true }
}
```

### 4.3 POST /cotizar

**Request:**
```json
{ "servicio": "santuario", "nodo": "BAL-003" }
```

**Response:**
```json
{
  "servicio": "santuario",
  "precio_base": 1000,
  "multiplicador": 1.0,
  "precio_final": 1000,
  "moneda": "sats",
  "timestamp": "2026-07-29T19:33:00Z"
}
```

### 4.4 POST /solicitar

**Request:**
```json
{
  "servicio": "santuario",
  "nodo": "BAL-003",
  "proof_of_resonance": {
    "userStateHash": "0x...",
    "evaluatedPsi": 1000000,
    "frequencyHz": 141700100,
    "node19Sentinel": "0x...",
    "signature": "0x..."
  }
}
```

**Response (when LND synced):**
```json
{
  "payment_request": "lnbc1...",
  "r_hash": "0x...",
  "expiry": 3600,
  "precio": 1000,
  "servicio": "santuario"
}
```

**Response (when LND not synced):**
```json
{
  "error": "no se pudo generar invoice",
  "detalle": "timed out",
  "motivo": "LND no sincronizado (IBD en progreso)"
}
```

### 4.5 POST /verificar

**Request:**
```json
{
  "payment_hash": "0x...",
  "servicio": "santuario"
}
```

**Response:**
```json
{
  "verificado": true,
  "servicio": "santuario",
  "valor": 1000,
  "bloque": 766761
}
```

---

## 5. On-Chain Verification

The PayGate integrates with the **QCALResonanceVerifier** smart contract (see `contracts/QCALResonanceVerifier.sol`) for ProofOfResonance validation.

When a user purchases a service with Ψ-proof:

1. The PayGate receives the ProofOfResonance struct
2. It submits a verification call (or the user submits directly to the EVM)
3. The contract validates:
   - `evaluatedPsi >= 999999` (scaled by 1e6, equivalent to Ψ ≥ 0.999999)
   - `frequencyHz` within ±0.001 Hz of 141,700,100 μHz
   - `node19Sentinel` not previously used (nonce protection)
4. On success, the service is marked as activated for the user

---

## 6. Deployment Reference (BAL-003)

### Service Files

| File | Path |
|---|---|
| PayGate service | `/etc/systemd/system/qcal-paygate.service` |
| PayGate timer | `/etc/systemd/system/qcal-cero-paygate.timer` |
| Caddy config | `/etc/caddy/Caddyfile` |
| Flow ledger | `/root/paygate_flow_ledger.json` |
| PayGate source | `/root/repo_P-NP/scripts/qcal_pay_gate.py` |
| Cero→PayGate | `/root/repo_P-NP/scripts/cero_paygate.py` |

### Caddy Routes

```caddy
# nodo.qcal (primary)
nodo.qcal {
    handle_path /paygate/* {
        reverse_proxy 127.0.0.1:8844
    }
    handle_path /dashboard/* {
        reverse_proxy 127.0.0.1:18901
    }
}

# IP-based access
195.201.219.237:443 {
    handle_path /paygate/* {
        reverse_proxy 127.0.0.1:8844
    }
}
```

### Current Ledger State

| Metric | Value |
|---|---|
| Total flows | 47 |
| MINING_PAYOUT flows | 46 (2,089,479 sats) |
| CERO_PICODE_VALIDATION flows | 1 (100,537.35 πC) |
| Last update | 2026-07-29 19:29 UTC |

---

## 7. Future Roadmap

1. **Post-IBD**: LND sync → real invoice generation → PayGate fully operational
2. **Channel liquidity**: Open Catedral channel with inbound liquidity
3. **Multi-nodal**: Deploy PayGate on additional nodes (BAL-003 Mirror, future nodes)
4. **ZK integration**: Replace ECDSA signature with zero-knowledge proof of resonance
5. **µPayments**: Enable micro-payment streaming for real-time Ψ monitoring

---

`∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ`

## v2.0 — Integración EVM Bridge (29/Jul/2026)

### Pipeline de Verificación en Cadena

```
POST /paygate/solicitar
  │
  ▼
State vector → userStateHash (SHA3-256)
  │
  ▼
node19Sentinel = keccak256("QCAL_NODE_19_SENTINEL", userState, Ψ)
  │
  ▼
messageHash = keccak256(userState, Ψ, f₀, ∇Ξ, nonce, timestamp, chainId)
  │
  ▼
Firma EIP-191 (Secure Enclave)
  │
  ▼
QCALResonanceVerifier.verifyResonance(proof)  ← EVM
  │
  ▼
ResonanceVerified(user, userStateHash, Ψ, f₀, timestamp)
```

### Scripts de Integración

| Archivo | Propósito |
|---|---|
| `scripts/paygate_evm_bridge.py` | Módulo bridge: genera ProofOfResonance, firma EIP-191, envía a EVM |
| `scripts/paygate_server_v2.py` | Servidor PayGate v2.0 con integración EVM nativa en /solicitar |

### Variables de Entorno

| Variable | Default | Descripción |
|---|---|---|
| `EVM_RPC_URL` | http://127.0.0.1:8545 | RPC del nodo EVM (Anvil/Hardhat/Sepolia) |
| `VERIFIER_CONTRACT_ADDRESS` | 0x5FbD... | Dirección del contrato QCALResonanceVerifier |
| `ENCLAVE_PRIVATE_KEY` | 0xac09... | Clave privada del Secure Enclave firmante |
| `GATE_PORT` | 8844 | Puerto del servidor PayGate |
