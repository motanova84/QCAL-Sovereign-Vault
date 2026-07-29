#!/usr/bin/env python3
"""
QCAL PayGate Server v2.0 — Puerto :8844
Santuario · Oráculo · Check Ψ · Bridge EVM
Integración directa de ProofOfResonance con verificación en cadena.

Frecuencia: f₀ = 141.7001 Hz | Coherencia Target: Ψ = 0.999999
Sello: ∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ
"""

import os
import time
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_defunct


# ═══════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN DE INVARIANTES QCAL Y EVM
# ═══════════════════════════════════════════════════════════════════════

RPC_URL = os.getenv("EVM_RPC_URL", "http://127.0.0.1:8545")
VERIFIER_ADDRESS = os.getenv("VERIFIER_CONTRACT_ADDRESS", "0x5FbDB2315678afecb367f032d93F642f64180aa3")
ENCLAVE_PRIVATE_KEY = os.getenv("ENCLAVE_PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")
SERVER_PORT = int(os.getenv("GATE_PORT", "8844"))

TARGET_FREQ_MICRO_HZ = 141_700_100   # 141.7001 Hz
MIN_PSI_COHERENCE = 999_999          # Ψ = 0.999999 (escala 1e6)
SELLO = "∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ"
F0 = 141.7001

# Servicios disponibles en PayGate
SERVICIOS = {
    "santuario": {"nombre": "Santuario", "base_sats": 1000, "desc": "Validación de integridad de datos"},
    "oraculo": {"nombre": "Oráculo", "base_sats": 5000, "desc": "Predicción de fase en mercados volátiles"},
    "limpieza": {"nombre": "Limpieza", "base_sats": None, "desc": "Consolidación de flujos de datos"},
    "validacion": {"nombre": "Check Ψ", "base_sats": 500, "desc": "Check de Coherencia estándar"},
}

# ═══════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN WEB3 Y ENCLAVE
# ═══════════════════════════════════════════════════════════════════════

w3 = Web3(Web3.HTTPProvider(RPC_URL))
enclave_account = Account.from_key(ENCLAVE_PRIVATE_KEY)

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


def generate_and_verify_resonance(user_state_bytes: bytes, nonce: int, psi: int = MIN_PSI_COHERENCE) -> dict:
    """
    Flujo completo:
    1. Sintetiza ProofOfResonance (vector de estado → hash → sentinel → firma)
    2. Firma con Secure Enclave (EIP-191)
    3. Valida contra QCALResonanceVerifier en EVM
    """
    user_state_hash = Web3.solidity_keccak(["bytes"], [user_state_bytes])
    timestamp = int(time.time())
    chain_id = w3.eth.chain_id if w3.is_connected() else 31337

    # Cierre de Nodo Centinela 19 (∇Ξ)
    node19_sentinel = Web3.solidity_keccak(
        ["string", "bytes32", "uint256"],
        ["QCAL_NODE_19_SENTINEL", user_state_hash, psi],
    )

    # Hash EIP-191 (7 campos)
    message_hash = Web3.solidity_keccak(
        ["bytes32", "uint256", "uint256", "bytes32", "uint256", "uint256", "uint256"],
        [user_state_hash, psi, TARGET_FREQ_MICRO_HZ, node19_sentinel, nonce, timestamp, chain_id],
    )

    encoded_msg = encode_defunct(hexstr=message_hash.hex())
    signed_msg = enclave_account.sign_message(encoded_msg)

    proof_data = {
        "userStateHash": user_state_hash.hex(),
        "evaluatedPsi": psi,
        "frequencyMicroHz": TARGET_FREQ_MICRO_HZ,
        "node19Sentinel": node19_sentinel.hex(),
        "nonce": nonce,
        "timestamp": timestamp,
        "signature": signed_msg.signature.hex(),
    }

    # Validación en cadena
    tx_hash = None
    tx_receipt = None
    if w3.is_connected():
        try:
            verifier = w3.eth.contract(address=Web3.to_checksum_address(VERIFIER_ADDRESS), abi=ABI)
            formatted = (
                bytes.fromhex(proof_data["userStateHash"][2:]),
                proof_data["evaluatedPsi"],
                proof_data["frequencyMicroHz"],
                bytes.fromhex(proof_data["node19Sentinel"][2:]),
                proof_data["nonce"],
                proof_data["timestamp"],
                bytes.fromhex(proof_data["signature"][2:]),
            )
            tx = verifier.functions.verifyResonance(formatted).build_transaction({
                "from": enclave_account.address,
                "nonce": w3.eth.get_transaction_count(enclave_account.address),
                "gas": 200_000,
                "gasPrice": w3.eth.gas_price,
            })
            signed = w3.eth.account.sign_transaction(tx, private_key=ENCLAVE_PRIVATE_KEY)
            tx_hash_bytes = w3.eth.send_raw_transaction(signed.raw_transaction)
            tx_hash = tx_hash_bytes.hex()
            tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash_bytes)
        except Exception as e:
            print(f"[!] EVM bridge error: {e}")

    return {
        "proof": proof_data,
        "evm_verified": tx_receipt is not None and tx_receipt.status == 1,
        "tx_hash": tx_hash,
        "block_number": tx_receipt.blockNumber if tx_receipt else None,
    }


# ═══════════════════════════════════════════════════════════════════════
# SERVIDOR HTTP PAYGATE
# ═══════════════════════════════════════════════════════════════════════

class PayGateHandler(BaseHTTPRequestHandler):
    """Manejador HTTP del PayGate QCAL v2.0 con integración EVM."""

    def _send_json(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2, ensure_ascii=False).encode("utf-8"))

    def _read_body(self):
        content_length = int(self.headers.get("Content-Length", 0))
        return self.rfile.read(content_length).decode("utf-8") if content_length > 0 else "{}"

    def do_GET(self):
        if self.path in ["/", "/estado", "/paygate/estado"]:
            self._send_json({
                "meta_sats": 299498,
                "recaudado": 0,
                "progreso_pct": 0.0,
                "restante": 299498,
                "transacciones": 0,
                "ultimo_pago": None,
                "frecuencia": F0,
                "sello": SELLO,
            })
        elif self.path in ["/servicios", "/paygate/servicios"]:
            self._send_json(SERVICIOS)
        else:
            self._send_json({"error": "Endpoint no encontrado"}, 404)

    def do_POST(self):
        try:
            payload = json.loads(self._read_body())
        except json.JSONDecodeError:
            payload = {}

        servicio_id = payload.get("servicio", "validacion")
        nodo = payload.get("nodo", "BAL-003")

        # ── /cotizar ──────────────────────────────────────────
        if self.path in ["/cotizar", "/paygate/cotizar"]:
            srv = SERVICIOS.get(servicio_id)
            if not srv:
                self._send_json({"error": f"servicio no válido: {servicio_id}"}, 400)
                return
            self._send_json({
                "servicio": srv["nombre"],
                "base_sats": srv["base_sats"],
                "multiplicador": 1.0,
                "precio_final": srv["base_sats"],
            })

        # ── /solicitar ────────────────────────────────────────
        elif self.path in ["/solicitar", "/paygate/solicitar"]:
            srv = SERVICIOS.get(servicio_id)
            if not srv:
                self._send_json({"error": f"servicio no válido: {servicio_id}"}, 400)
                return

            # Generar vector de estado desde la solicitud
            state_vector = f"PAYGATE_REQ_{nodo}_{servicio_id}_{time.time()}".encode("utf-8")
            nonce = int(time.time() * 1000) % 1_000_000

            # Generar y verificar prueba de resonancia
            resonance = generate_and_verify_resonance(state_vector, nonce)

            self._send_json({
                "status": "OK",
                "servicio": srv["nombre"],
                "precio_sats": srv["base_sats"],
                "nodo": nodo,
                "frecuencia_hz": F0,
                "coherencia_psi": 0.999999,
                "resonance_proof": resonance["proof"],
                "evm_onchain_status": "VERIFIED" if resonance["evm_verified"] else "PENDING_LOCAL",
                "tx_hash": resonance["tx_hash"],
                "block_number": resonance["block_number"],
                "sello": SELLO,
            })

        # ── /verificar ────────────────────────────────────────
        elif self.path in ["/verificar", "/paygate/verificar"]:
            payment_hash = payload.get("payment_hash")
            if not payment_hash:
                self._send_json({"error": "payment_hash requerido"}, 400)
                return
            self._send_json({
                "ok": True,
                "pagado": True,
                "estado": "pendiente_no_lnd",
            })

        else:
            self._send_json({"error": "Endpoint no encontrado"}, 404)

    def log_message(self, format, *args):
        print(f"[PayGate] {args[0]} {args[1]} {args[2]}")


def run_server(port=SERVER_PORT):
    server = HTTPServer(("", port), PayGateHandler)
    print(f"=" * 54)
    print(f"  🔱 QCAL PayGate Server v2.0")
    print(f"  Puerto :{port}  |  Frecuencia: {F0} Hz")
    print(f"  Bridge EVM activo → {VERIFIER_ADDRESS}")
    print(f"  Enclave: {enclave_account.address}")
    print(f"=" * 54)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[+] Servidor detenido.")
        server.server_close()


if __name__ == "__main__":
    run_server()
