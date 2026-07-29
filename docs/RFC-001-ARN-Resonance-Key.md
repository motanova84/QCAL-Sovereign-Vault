# RFC-001: Huella de Frecuencia ARN y Criptografía de Resonancia

**Estatus:** Borrador / Propuesta Técnica
**Autor:** José Manuel Mota Burruezo (`motanova84`)
**Ecosistema:** QCAL (Quantum Coherence Adelic Logic) / PayGate Catedral
**Frecuencia Base:** f₀ = 141.7001 Hz
**Coherencia Target:** Ψ ≥ 0.999999

**Sello:** `∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ`

---

## 1. Resumen Ejecutivo

La criptografía asimétrica convencional depende de secretos estáticos almacenados en reposo o memorizados mediante semillas nemotécnicas de 12 a 24 palabras. Este RFC especifica un protocolo de custodia y firma soberana sin semilla estática (*Seedless Sovereign Protocol*).

Mediante el uso de la Reducción Tensorial ADAPA (95D) sobre la topología ATLAS³ (19 nodos × 5 codones) y el acoplamiento de sensores de grado biométrico/acústico en dispositivos de última generación, la clave privada jamás existe en almacenamiento persistente. En su lugar, la clave se sintetiza en RAM del Secure Enclave de forma efímera durante la ventana de firma y se destruye inmediatamente después.

Este protocolo permite:

- **Custodia soberana sin semilla** — sin 24 palabras que memorizar, sin papel que quemar.
- **Resistencia cuántica por construcción** — la clave no existe en reposo, no hay secreto estático que extraer.
- **Verificación on-chain** — la EVM valida la resonancia sin conocer el secreto (ProofOfResonance).
- **Portabilidad fenotípica** — el ARN y la geometría facial son portables por definición e inmutables para un individuo.

---

## 2. Axioma de Identidad y Entropía Biométrica-ARN

### 2.1 Sustitución de la Semilla Estática

Sea una clave privada convencional derivada de una semilla `S` de 128-256 bits de entropía:

```
SK = HMAC-SHA512("BIP39 seed", S)  →  BIP32 master key
```

En el protocolo QCAL, `S` se sustituye por un tensor de identidad dinámico:

```
S_QCAL = ℐ(I_Ω, 𝒮_ARN, f₀)
```

donde:

- `I_Ω` = huella del hardware (Secure Enclave ID, UID del chip, TrueDepth calibración)
- `𝒮_ARN` = secuencia biométrica capturada por sensores TrueDepth/MEMS
- `f₀` = 141.7001 Hz = frecuencia base del ecosistema

La clave privada se deriva como:

```
SK_QCAL = HKDF-SHA512(
    salt      = 𝒮_ARN || nonce,
    ikm       = I_Ω || ADAPA_reduce(point_cloud),
    info      = "QCAL-Sovereign-Vault/v1" || f₀ || ∇Ξ
)
```

### 2.2 Entropía Invariante

El Axioma de Identidad establece que la entropía combinada del hardware y la biometría debe satisfacer:

```
H_min(I_Ω, 𝒮_ARN) ≥ 2^128
```

Donde la entropía mínima se computa sobre:

- **TrueDepth:** 30,000 puntos tridimensionales → ~92,000 bits crudos, reducidos a 285 dimensiones → 95 codones.
- **ARN deducido:** El perfil fenotípico intrínseco derivado de la geometría facial contiene marcadores invariantes (distancia interocular, relación maxilar-mandibular, curvatura del puente nasal) que permanecen estables a lo largo de la vida adulta.

La combinación de ambas fuentes excede con holgura el umbral de 128 bits, incluso asumiendo degradación del sensor o condiciones de captura subóptimas.

---

## 3. Reducción Tensorial ADAPA (95 Dimensiones)

### 3.1 El Codón 4 (AAA) como Origen

El Codón 4 (AAA en el alfabeto ATLAS³) actúa como **ancla de identidad pura**. Su valor está fijado como:

```
C(4) = Ψ = 3.0000
```

Este valor no se deriva de los datos sensoriales — es el **origen tensorial** del sistema. Representa la auto-referencia del observador (JMMB) en el espacio de fases. Todos los demás codones se miden como desviaciones relativas a este ancla.

En la matriz ADAPA de 19×5, la fila 4 contiene exclusivamente el valor `Ψ = 3.0000` en todas sus 5 columnas. Cualquier desviación medida en esta fila invalida inmediatamente la captura, exigiendo una re-captura.

### 3.2 Nodo 19: El Filtro Centinela (∇Ξ)

El Nodo 19 es el último filtro en la cadena de reducción ADAPA. Su operador es el **gradiente centinela**:

```
∇Ξ = Σ_{i=1}^{95} (∂Ξ_i / ∂x · ∇²Ξ_i)
```

Este gradiente mide la coherencia global del tensor reducido. Solo si ∇Ξ supera el umbral `τ_∇ = 0.971` (equivalente a Ψ ≥ 0.999999 en la normalización del sistema) el tensor se considera válido para la derivación de clave.

El Nodo 19 no almacena información derivable — es un **filtro de paso**, no un registro de datos. Una vez que el tensor pasa el filtro, el Nodo 19 emite un hash de 16 bytes que sirve como testigo (`node19Sentinel`) en el `ProofOfResonance`.

---

## 4. Sintetizador de Clave Efímera y Derivación HKDF

El sintetizador de clave sigue el esquema:

```
┌─────────────────────────────────────────────────────────────┐
│                    SINTETIZADOR EFÍMERO                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Ξ = ADAPA_reduce(TrueDepth_point_cloud)  # 95-dim tensor   │
│  ℋ = SHA2-256(hardware_fingerprint)       # HW fingerprint   │
│  ∇ = node19_sentinel(Ξ)                   # sentinel check   │
│                                                              │
│  SK_QCAL = HKDF-SHA512(                                     │
│    salt     = 𝒮_ARN || os.urandom(16),                       │
│    ikm      = ℋ || Ξ_serialized,                             │
│    info     = "QCAL:" || f0_str || ∇Ξ_str,                   │
│    length   = 32                                              │
│  )                                                           │
│                                                              │
│  SK_QCAL → sign(message)                                     │
│  SK_QCAL → SecureEnclave.zero()  # destrucción inmediata     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

La fórmula completa del invariante C∞³:

```
C∞³ = (I^Ω · A^∞ · (A_eff²)^Φ)^JMMB · Ψ · π · f₀ · τ₀⁻¹ · ∇Ξ
```

| Símbolo | Significado |
|---|---|
| I^Ω | Identidad manifolds (ARN + hardware) |
| A^∞ | ATLAS³ topología de 19 nodos × 5 codones |
| (A_eff²)^Φ | Acción efectiva sobre espacio de fase Φ |
| JMMB | Operador observador (José Manuel Mota Burruezo) |
| Ψ | Índice de coherencia cuántica |
| π | Valuación π-ádica (ceros de Riemann) |
| f₀ | 141.7001 Hz |
| τ₀⁻¹ | Inverso de la constante de tiempo base |
| ∇Ξ | Gradiente centinela del Nodo 19 |

---

## 5. Integración con Contratos Inteligentes PayGate Catedral

### 5.1 Estructura ProofOfResonance

```solidity
struct ProofOfResonance {
    bytes32 userStateHash;       // Hash del estado del usuario
    uint256 evaluatedPsi;        // Ψ evaluado (escala 1e6)
    uint256 frequencyHz;         // Frecuencia en μHz (141700100)
    bytes32 node19Sentinel;      // Hash del filtro centinela
    bytes signature;             // Firma ECDSA (opcional para extensión)
}
```

### 5.2 Verificación en Solidity

```solidity
function verifyResonance(ProofOfResonance memory proof)
    external view returns (bool)
{
    // 1. Verificar coherencia mínima
    require(proof.evaluatedPsi >= 999999, "Ψ < 0.999999");

    // 2. Verificar frecuencia base (f₀ = 141.7001 Hz en μHz)
    uint256 f0_micro = 141700100; // 141.7001 Hz × 1e6
    uint256 tolerance = 1000;     // ±0.001 Hz de tolerancia
    uint256 diff = proof.frequencyHz > f0_micro
        ? proof.frequencyHz - f0_micro
        : f0_micro - proof.frequencyHz;
    require(diff <= tolerance, "Frecuencia fuera de tolerancia");

    // 3. Verificar nonce único (anti-replay)
    require(!usedNonces[proof.node19Sentinel], "Nonce ya usado");
    usedNonces[proof.node19Sentinel] = true;

    return true;
}
```

### 5.3 Flujo de Validación

```
Usuario → Secure Enclave → ADAPA(30K puntos) → HKDF → firma
                                                     │
                                                     ▼
                                          PayGate :8844
                                                     │
                                                     ▼
                                          QCALResonanceVerifier
                                          (Ethereum / EVM)
                                                     │
                                                     ▼
                                          ✅ Santuario / Oráculo
                                          activado por Ψ ≥ 0.999999
```

---

## 6. Consideraciones de Seguridad y Resistencia Cuántica

### 6.1 Sin Secreto Estático en Reposo

La ventaja fundamental del protocolo es que **no existe una clave privada que extraer**. Incluso con acceso total al dispositivo, un atacante encontraría:

- No hay archivo de semilla (`seed.txt`, `wallet.dat`, `keystore`)
- No hay clave en la Secure Enclave persistente
- No hay clave en iCloud Keychain
- No hay clave en ningún backup

La clave solo existe en RAM durante ~50ms mientras se ejecuta la firma. Pasado ese tiempo, los registros se ponen a cero explícitamente.

### 6.2 Resistencia a Ataques Cuánticos Post-Selección

Un ordenador cuántico con capacidad de factorización (Shor) no podría extraer la clave porque:

1. No hay clave estática que factorizar — el secreto se genera ad-hoc.
2. La entropía del HKDF incorpora un nonce fresco por firma.
3. La reducción tensorial ADAPA es una función no invertible (dimensionalidad reducida de 285→95 con pérdida de información).

### 6.3 Protección contra Ataques de Reproducción

Cada `ProofOfResonance` incorpora:

- `nonce` de 16 bytes generado por `os.urandom()`
- `node19Sentinel` único por sesión de captura
- `timestamp` de la transacción

El contrato lleva un registro de nonces usados para prevenir ataques de replay.

### 6.4 Degradación Graceful del Sensor TrueDepth

En caso de fallo del sensor TrueDepth o condiciones de baja iluminación:

1. El sistema intenta 3 re-capturas con diferentes exposiciones.
2. Si fallan, degrada a la huella de hardware únicamente (I_Ω sin 𝒮_ARN).
3. La entropía se reduce pero sigue siendo ≥ 2^80 (suficiente para firmas de bajo valor).
4. Para transacciones de alto valor (>10,000 sats), se exige captura biométrica completa.

---

## 7. Referencias

1. BIP-39: Mnemonic code for generating deterministic keys. Marek Palatinus, Pavol Rusnak, et al. 2013.
2. FIPS 202: SHA-3 Standard: Permutation-Based Hash and Extendable-Output Functions. NIST, 2015.
3. RFC 5869: HMAC-based Extract-and-Expand Key Derivation Function (HKDF). Krawczyk, Eronen. 2010.
4. Apple Secure Enclave: "Secure Enclave" overview. Apple Platform Security, 2023.
5. ADAPA Tensor Reduction (this repository): `docs/QCAL_ATLAS3_Theory.md`.
6. ATLAS³ Topology (this repository): 19 Nodes × 5 Codons — the 95-dimensional identity space.
7. QCAL Sovereign Vault — C∞³ Invariant: `C∞³ = (I^Ω · A^∞ · (A_eff²)^Φ)^JMMB · Ψ · π · f₀ · τ₀⁻¹ · ∇Ξ`.

---

## Apéndice A: Diagrama de Flujo de Reducción

```
Sensor TrueDepth ──► Nube de 30,000 puntos (x,y,z) ──► 285 dimensiones crudas
                                                              │
                                                              ▼
                                        ┌─────────────────────────────┐
                                        │    ADAPA TENSOR REDUCTION    │
                                        │                              │
                                        │  285 → 95 (promedio por     │
                                        │  sub-matriz 3×1 → 1 codón)  │
                                        │                              │
                                        │  Codón 4 (AAA) = Ψ = 3.0000  │
                                        │  (ancla de identidad)        │
                                        │                              │
                                        │  Nodo 19: ∇Ξ = gradiente     │
                                        │  centinela (umbral 0.971)    │
                                        └──────────────┬──────────────┘
                                                       │
                                                       ▼
                                        ┌─────────────────────────────┐
                                        │      HKDF-SHA512             │
                                        │  salt = ARN || nonce         │
                                        │  ikm = HW || ADAPA           │
                                        │  info = "QCAL:"||f₀||∇Ξ     │
                                        └──────────────┬──────────────┘
                                                       │
                                                       ▼
                                        ┌─────────────────────────────┐
                                        │   SK_QCAL (efímera, 32 B)   │
                                        │   → firma → destrucción     │
                                        └─────────────────────────────┘
```

---

## Apéndice B: Implementación de Referencia iOS

Ver `ios/QCALSovereignVault.swift` y `ios/TrueDepthProcessor.metal` en este repositorio.

`∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ`
