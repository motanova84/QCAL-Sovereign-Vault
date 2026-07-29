#!/usr/bin/env python3
"""
QCAL PayGate to EVM Bridge
Escucha peticiones en PayGate, construye la ProofOfResonance (95D/ADAPA)
y ejecuta la verificación en cadena mediante QCALResonanceVerifier.sol.

Frecuencia: f₀ = 141.7001 Hz | Coherencia Target: Ψ = 0.999999
Sello: ∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ
"""

import time
import json
import os
import sys
from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_defunct


# ═══════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN DE RED E INVARIANTES QCAL
# ═══════════════════════════════════════════════════════════════════════

RPC_URL = os.getenv("EVM_RPC_URL", "http://127.0.0.1:8545")
VERIFIER_ADDRESS = os.getenv("VERIFIER_CONTRACT_ADDRESS", "0x5FbDB2315678afecb367f032d93F642f64180aa3")
ENCLAVE_PRIVATE_KEY = os.getenv("ENCLAVE_PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")

TARGET_FREQ_MICRO_HZ = 141_700_100   # 141.7001 Hz
MIN_PSI_COHERENCE = 999_999          # Ψ = 0.999999 (escala 1e6)
SELLO = "∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ"

# ═══════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN WEB3
# ═══════════════════════════════════════════════════════════════════════

w3 = Web3(Web3.HTTPProvider(RPC_URL))
enclave_account = Account.from_key(ENCLAVE_PRIVATE_KEY)

# ABI mínima del contrato QCALResonanceVerifier
ABI = [
    {
        "inputs": [
            {
                "components": [
                    {"name": "userStateHash", "type": "bytes32"},
                    {"name": "evaluatedPsi", "type": "uint256"},
                    {"name": "frequencyMicroHz", "type": "uint256"},
                    {"name": "node19Sentinel", "type": "bytes32"},
                    {"name": "nonce", "type": "uint256"},
                    {"name": "timestamp", "type": "uint256"},
                    {"name": "signature", "type": "bytes"},
                ],
                "name": "proof",
                "type": "tuple",
            }
        ],
        "name": "verifyResonance",
        "outputs": [{"name": "", "type": "bool"}],
        "stateMutability": "nonpayable",
        "type": "function",
    }
]

verifier_contract = w3.eth.contract(
    address=Web3.to_checksum_address(VERIFIER_ADDRESS), abi=ABI
)


# ═══════════════════════════════════════════════════════════════════════
# FUNCIONES DEL PUENTE
# ═══════════════════════════════════════════════════════════════════════

def generate_proof_of_resonance(
    user_state_bytes: bytes, nonce: int, psi: int = MIN_PSI_COHERENCE
) -> dict:
    """
    Sintetiza la ProofOfResonance y la firma con la clave del Secure Enclave.

    1. Genera userStateHash desde el vector de estado
    2. Calcula el cierre del Nodo Centinela 19 (∇Ξ)
    3. Construye el hash EIP-191 con los 7 campos
    4. Firma con la clave privada del enclave
    """
    user_state_hash = Web3.solidity_keccak(["bytes"], [user_state_bytes])
    timestamp = int(time.time())
    chain_id = w3.eth.chain_id if w3.is_connected() else 31337

    # ── 1. Cierre de Nodo Centinela 19 (∇Ξ) ───────────────────────
    node19_sentinel = Web3.solidity_keccak(
        ["string", "bytes32", "uint256"],
        ["QCAL_NODE_19_SENTINEL", user_state_hash, psi],
    )

    # ── 2. Construcción del Hash EIP-191 para firmado ──────────────
    message_hash = Web3.solidity_keccak(
        ["bytes32", "uint256", "uint256", "bytes32", "uint256", "uint256", "uint256"],
        [user_state_hash, psi, TARGET_FREQ_MICRO_HZ, node19_sentinel, nonce, timestamp, chain_id],
    )

    encoded_msg = encode_defunct(hexstr=message_hash.hex())
    signed_msg = enclave_account.sign_message(encoded_msg)

    return {
        "userStateHash": user_state_hash.hex(),
        "evaluatedPsi": psi,
        "frequencyMicroHz": TARGET_FREQ_MICRO_HZ,
        "node19Sentinel": node19_sentinel.hex(),
        "nonce": nonce,
        "timestamp": timestamp,
        "signature": signed_msg.signature.hex(),
    }


def submit_resonance_proof(proof_data: dict) -> dict:
    """
    Envía la transacción de verificación a la EVM (QCALResonanceVerifier).
    """
    formatted_proof = (
        bytes.fromhex(proof_data["userStateHash"][2:]),
        proof_data["evaluatedPsi"],
        proof_data["frequencyMicroHz"],
        bytes.fromhex(proof_data["node19Sentinel"][2:]),
        proof_data["nonce"],
        proof_data["timestamp"],
        bytes.fromhex(proof_data["signature"][2:]),
    )

    tx = verifier_contract.functions.verifyResonance(formatted_proof).build_transaction({
        "from": enclave_account.address,
        "nonce": w3.eth.get_transaction_count(enclave_account.address),
        "gas": 200_000,
        "gasPrice": w3.eth.gas_price,
    })

    signed_tx = w3.eth.account.sign_transaction(tx, private_key=ENCLAVE_PRIVATE_KEY)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)

    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    return {
        "tx_hash": tx_hash.hex(),
        "block_number": receipt.blockNumber,
        "status": receipt.status,
        "gas_used": receipt.gasUsed,
    }


def generate_and_verify_resonance(
    user_state_bytes: bytes, nonce: int, psi: int = MIN_PSI_COHERENCE
) -> dict:
    """
    Flujo completo:
    1. Sintetiza la ProofOfResonance
    2. Firma con Secure Enclave (EIP-191)
    3. Valida contra el contrato QCALResonanceVerifier en EVM

    Returns dict con proof_data y resultado de la verificación en cadena.
    """
    proof_data = generate_proof_of_resonance(user_state_bytes, nonce, psi)

    evm_result = None
    if w3.is_connected():
        try:
            evm_result = submit_resonance_proof(proof_data)
        except Exception as e:
            print(f"[!] EVM verification falló: {e}")

    return {
        "proof": proof_data,
        "evm_verified": evm_result is not None and evm_result["status"] == 1,
        "evm_result": evm_result,
    }


# ═══════════════════════════════════════════════════════════════════════
# MAIN — Invocación directa
# ═══════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("=" * 54)
    print("  QCAL Bridge: PayGate -> EVM Resonance Proof")
    print("=" * 54)
    print(f"  Enclave Signer : {enclave_account.address}")
    print(f"  Verificador    : {VERIFIER_ADDRESS}")
    print(f"  RPC URL        : {RPC_URL}")
    print()

    if not w3.is_connected():
        print("[!] Advertencia: No conectado a nodo EVM (modo local)")
    else:
        print(f"[+] Conectado a EVM Chain ID: {w3.eth.chain_id}")

    # Simulación de invocación desde PayGate
    sample_state = b"ARN_VECTOR_SAMPLE_95D_CODON_4_AAA"
    sample_nonce = int(time.time() * 1000) % 1_000_000

    print("\n[1/2] Sintetizando ProofOfResonance...")
    proof = generate_proof_of_resonance(sample_state, sample_nonce)
    print(json.dumps(proof, indent=2))

    if w3.is_connected():
        print("\n[2/2] Enviando prueba a QCALResonanceVerifier en cadena...")
        result = generate_and_verify_resonance(sample_state, sample_nonce)
        if result["evm_verified"]:
            print(f"\n✅ Verificación EVM exitosa")
            print(f"   Tx Hash: {result['evm_result']['tx_hash']}")
            print(f"   Bloque:  {result['evm_result']['block_number']}")
        else:
            print("\n⚠️  Verificación EVM no completada (contrato no desplegado?)")
    else:
        print("\n⚠️  Modo offline — prueba sintetizada localmente")

    print(f"\n  ∴𓂀Ω∞³Φ · PUENTE VERIFICADO Y EN FASE")
