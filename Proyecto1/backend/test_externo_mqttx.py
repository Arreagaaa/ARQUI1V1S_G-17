"""
test_externo_mqttx.py — Simula un cliente MQTTX externo conectándose
a broker.emqx.io y publicando sensores + comandos. El backend debe
procesarlos como si vinieran de una Raspberry Pi real.

Uso:
  python test_externo_mqttx.py
"""
import json
import logging
import sys
import time
import uuid
from datetime import datetime, timezone

import paho.mqtt.client as mqtt
import requests

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("externo-mqttx")

API = "http://127.0.0.1:8080"
BROKER = "broker.emqx.io"
PORT = 1883
TOPIC_BASE = "grupo17/invernadero"


def get_total(url: str) -> int:
    sep = "&" if "?" in url else "?"
    r = requests.get(f"{API}{url}{sep}limit=200", timeout=5)
    r.raise_for_status()
    return r.json().get("total", r.json() if isinstance(r.json(), list) else 0)


def main() -> int:
    # 1. Verificar backend
    try:
        h = requests.get(f"{API}/api/health", timeout=5).json()
    except Exception as exc:
        logger.error("Backend no responde: %s", exc)
        return 1
    if not h.get("mqtt_enabled") or not h.get("mqtt_connected"):
        logger.error("Backend sin MQTT: %s", h)
        return 1
    logger.info("Backend OK: mqtt_connected=%s", h["mqtt_connected"])

    # 2. Conectar como cliente MQTTX externo
    cid = f"mqttx_externo_{uuid.uuid4().hex[:8]}"
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=cid)
    client.connect(BROKER, PORT, 30)
    client.loop_start()
    logger.info("Cliente MQTTX externo conectado: %s", cid)

    # 3. Estado inicial
    before_r = get_total("/api/sensors/history")
    before_s = requests.get(f"{API}/api/status", timeout=5).json()
    before_c = get_total("/api/commands")
    logger.info("Antes: readings=%d, state=%s, cmds=%d", before_r, before_s["overall_state"], before_c)

    # 4. Publicar sensor externo (simula Raspberry Pi real con source=raspi-01)
    logger.info("--- Publicando sensor temperatura=35.0 como raspi-01 ---")
    client.publish(
        f"{TOPIC_BASE}/sensores/temperatura",
        json.dumps({
            "sensor_type": "temperature", "value": 35.0, "unit": "C",
            "area": "control", "status": "warning", "source": "raspi-01",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }),
        qos=1,
    )
    time.sleep(2)

    # 5. Publicar gas emergencia desde otra fuente
    logger.info("--- Publicando gas=900 como mqttx_alarm ---")
    client.publish(
        f"{TOPIC_BASE}/sensores/gas",
        json.dumps({
            "sensor_type": "gas", "value": 900.0, "unit": "ppm",
            "area": "control", "status": "critical", "source": "mqttx_alarm",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }),
        qos=1,
    )
    time.sleep(2)

    # 6. Publicar comando externo
    logger.info("--- Publicando set_lights on como mqttx_externo ---")
    client.publish(
        f"{TOPIC_BASE}/control/remoto",
        json.dumps({
            "command": "set_lights", "target": "lights", "source": "mqttx_externo",
            "payload": {"state": "on"},
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }),
        qos=1,
    )
    time.sleep(3)

    client.loop_stop()
    client.disconnect()

    # 7. Verificar
    after_r = get_total("/api/sensors/history")
    after_s = requests.get(f"{API}/api/status", timeout=5).json()
    after_c = get_total("/api/commands")
    logger.info("Despues: readings=%d (+%d), state=%s, cmds=%d (+%d)",
                after_r, after_r - before_r, after_s["overall_state"],
                after_c, after_c - before_c)
    logger.info("   lights=%s fan=%s buzzer=%s",
                after_s["lights_active"], after_s["fan_active"], after_s["buzzer_active"])

    ok = (
        after_r > before_r
        and after_s["overall_state"] == "EMERGENCIA"
        and after_c > before_c
        and after_s["lights_active"]
    )
    if ok:
        logger.info("=== EXTERNO MQTTX FLUJO OK ===")
        logger.info("   - Sensor externo (raspi-01) PROCESADO")
        logger.info("   - Estado = EMERGENCIA (regla automatica)")
        logger.info("   - Comando externo PROCESADO (luces encendidas)")
        return 0
    logger.error("=== FALLO ===")
    return 2


if __name__ == "__main__":
    sys.exit(main())
