#!/usr/bin/env python3
"""
QCAL CERO->PAYGATE v1.1 - Transmutacion inyecta valor directo
Puente: Cero de Riemann -> piCODE -> Credito de Validacion Noetica
BAL-003 | f0 = 141.7001 Hz
v1.1: +dedup por batch, +semilla de coherencia, +control de frecuencia
"""
import json, hashlib, logging, os, sys
from datetime import datetime, timezone
from pathlib import Path

SELLO = "∴𓂀Ω∞³Φ · TUYOYOTU · HECHO ESTÁ"
F0 = 141.7001
TRACKING_FILE = Path("/root/picode_blocks/cero_tracking.json")
FLOW_LEDGER = Path("/root/paygate_flow_ledger.json")
CREDIT_PCT = float(os.environ.get("CERO_PAYGATE_PCT", "10.0"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [CERO>GATE] %(message)s",
    handlers=[logging.FileHandler("/var/log/cero_paygate.log"), logging.StreamHandler()],
)
log = logging.getLogger("cero_paygate")


def cargar_tracking():
    if not TRACKING_FILE.exists():
        log.error("Tracking no encontrado: %s", TRACKING_FILE)
        return None
    try:
        with open(TRACKING_FILE) as f:
            return json.load(f)
    except Exception as e:
        log.error("Error tracking: %s", e)
        return None


def ultimo_batch(tracking):
    batches = tracking.get("batches", tracking.get("bloques", []))
    return batches[-1] if batches else None


def batch_ya_procesado(desde, hasta, ledger):
    """Dedup: verifica si este batch ya fue registrado en el ledger."""
    for f in ledger.get("flujos", []):
        if f.get("tipo") == "CERO_PICODE_VALIDATION":
            if f.get("batch_desde") == str(desde) and f.get("batch_hasta") == str(hasta):
                return True
    return False


def semilla_coherencia(desde, hasta, total, credito):
    """Genera la semilla de coherencia para este ciclo."""
    raw = f"{desde}-{hasta}|{total}|{credito}|{F0}|{SELLO}"
    return hashlib.sha3_512(raw.encode()).hexdigest()[:32]


def procesar():
    log.info("=" * 54)
    log.info("CERO>PAYGATE v1.1 - Iniciando (credito: %.1f%%)", CREDIT_PCT)

    tracking = cargar_tracking()
    if not tracking:
        sys.exit(1)

    batch = ultimo_batch(tracking)
    if not batch:
        log.error("Sin batches en tracking")
        sys.exit(1)

    total = batch.get("total_picode", 0)
    credito = total * (CREDIT_PCT / 100.0)
    d = batch.get("desde", "?")
    h = batch.get("hasta", "?")

    log.info("Batch [%s->%s]: %.2f piC -> credito %.2f piC", d, h, total, credito)

    # ---- DEDUP ----
    try:
        ledger = {"flujos": []}
        if FLOW_LEDGER.exists():
            with open(FLOW_LEDGER) as f:
                ledger = json.load(f)
    except Exception as e:
        log.error("Error leyendo ledger: %s", e)
        sys.exit(1)

    if batch_ya_procesado(d, h, ledger):
        log.info("⏭️  Batch %s->%s ya procesado — omitiendo (dedup)", d, h)
        log.info("CERO>PAYGATE COMPLETADO (sin cambios)")
        sys.exit(0)

    # ---- GENERAR FLUJO ----
    nonce = os.urandom(8).hex()
    semilla = semilla_coherencia(d, h, total, credito)

    flujo = {
        "tipo": "CERO_PICODE_VALIDATION",
        "version": "1.1",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "batch_desde": str(d),
        "batch_hasta": str(h),
        "n_ceros": batch.get("n_ceros", 100),
        "total_picode_batch": round(total, 2),
        "credito_picode": round(credito, 2),
        "porcentaje": CREDIT_PCT,
        "semilla_coherencia": semilla,
        "hash_validacion": semilla[:16],
        "nonce": nonce,
        "frecuencia_hz": F0,
        "sello": SELLO,
    }

    try:
        ledger.setdefault("flujos", []).append(flujo)
        ledger["flujos"] = ledger["flujos"][-1000:]
        with open(FLOW_LEDGER, "w") as f:
            json.dump(ledger, f, indent=2, ensure_ascii=False)
        log.info("✅ Registrado: %.2f piC | Hash: %s", credito, semilla[:8])
    except Exception as e:
        log.error("Error escribiendo ledger: %s", e)
        sys.exit(1)

    log.info("CERO>PAYGATE COMPLETADO")
    log.info("=" * 54)


if __name__ == "__main__":
    procesar()
