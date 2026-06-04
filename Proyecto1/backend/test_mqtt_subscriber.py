"""
test_mqtt_subscriber.py — Verifica que el subscriber del backend recibe
y persiste mensajes MQTT publicados externamente.

Simula lo que haría un integrante del grupo usando MQTTX Web:
publica un comando en `grupo17/invernadero/control/remoto` y
comprueba que el backend lo guardó en MongoDB.

Uso:
  python test_mqtt_subscriber.py
"""

import json
import logging
import sys
import time
import uuid
from datetime import datetime, timezone

import paho.mqtt.client as mqtt
import requests

from app.config import get_settings

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("mqtt-test")

API = "http://127.0.0.1:8080"


def get_commands_count() -> int:
    r = requests.get(f"{API}/api/commands?limit=200", timeout=5)
    r.raise_for_status()
    return r.json()["total"]


def main() -> int:
    settings = get_settings()
    base = settings.mqtt_base_topic
    host = settings.mqtt_host
    port = settings.mqtt_port

    # 1. Verificar backend arriba
    try:
        health = requests.get(f"{API}/api/health", timeout=5).json()
    except Exception as exc:
        logger.error("Backend no responde: %s", exc)
        return 1
    logger.info("Backend health: %s", health)
    if not health.get("mqtt_enabled"):
        logger.warning("Backend tiene MQTT deshabilitado. Activa ENABLE_MQTT=true en .env")
        return 1

    # 2. Contar comandos antes
    before = get_commands_count()
    logger.info("Comandos en MongoDB antes: %d", before)

    # 3. Publicar comando via MQTT (simulando MQTTX Web)
    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id=f"test_mqtt_subscriber_{uuid.uuid4().hex[:8]}",
    )
    client.connect(host, port, keepalive=30)
    client.loop_start()

    payload = {
        "command": "set_pump",
        "target": "pump",
        "source": "mqttx_external_test",
        "payload": {"state": "on", "area": "area_1"},
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    topic = f"{base}/control/remoto"
    logger.info("Publicando en %s: %s", topic, json.dumps(payload))
    client.publish(topic, json.dumps(payload), qos=1)

    # 4. Esperar a que el backend lo procese
    time.sleep(3)

    client.loop_stop()
    client.disconnect()

    # 5. Contar comandos después
    after = get_commands_count()
    logger.info("Comandos en MongoDB después: %d", after)

    if after > before:
        logger.info("✅ SUBSCRIBER OK — comando MQTT externo fue recibido y persistido.")
        return 0
    else:
        logger.error("❌ SUBSCRIBER NO RESPONDE — comando no apareció en MongoDB")
        logger.error("   (El backend puede tener suscriptores desconectados o el topic no coincide)")
        return 2


if __name__ == "__main__":
    sys.exit(main())
