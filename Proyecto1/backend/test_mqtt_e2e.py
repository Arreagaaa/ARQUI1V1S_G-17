"""
test_mqtt_e2e.py — Prueba integral end-to-end simulando lo que un
integrante del grupo haría con MQTTX Web:

1. Publica lecturas de sensor (simula la Raspberry Pi) → backend las recibe
   y las guarda en MongoDB → estado global se actualiza.
2. Publica un comando de control (simula botón en MQTTX) → backend lo
   procesa y guarda → dashboard lo refleja.

Uso:
  python test_mqtt_e2e.py
"""

import json
import logging
import time
import uuid
from datetime import datetime, timezone

import paho.mqtt.client as mqtt
import requests

from app.config import get_settings
from app.mqtt.mock_provider import MQTTMockProvider

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("e2e-test")
API = "http://127.0.0.1:8080"


def get_health():
    return requests.get(f"{API}/api/health", timeout=5).json()


def get_dashboard():
    return requests.get(f"{API}/api/dashboard", timeout=5).json()


def get_status():
    return requests.get(f"{API}/api/status", timeout=5).json()


def get_count(collection_path: str) -> int:
    sep = "&" if "?" in collection_path else "?"
    r = requests.get(f"{API}{collection_path}{sep}limit=200", timeout=5)
    r.raise_for_status()
    return r.json()["total"]


def publish(client, topic: str, payload: dict) -> None:
    client.publish(topic, json.dumps(payload), qos=1)
    logger.info("Publicado en %s: %s", topic, json.dumps(payload)[:100])


def assert_eq(label, expected, actual):
    ok = expected == actual
    icon = "✅" if ok else "❌"
    logger.info("%s %s: esperado=%s, actual=%s", icon, label, expected, actual)
    return ok


def main() -> int:
    settings = get_settings()
    base = settings.mqtt_base_topic

    h = get_health()
    if not h.get("mqtt_enabled") or not h.get("mqtt_connected"):
        logger.error("Backend no tiene MQTT activo/conectado: %s", h)
        return 1
    logger.info("Backend OK: %s", h)

    # Reset de modo a auto para que el test sea repetible.
    # Sin esto, un run previo que haya dejado mode=manual haría que
    # el estado quede en MODO_MANUAL en vez de EMERGENCIA.
    try:
        requests.post(f"{API}/api/control/mode", json={"mode": "auto"}, timeout=5)
    except Exception as exc:
        logger.warning("No se pudo resetear modo a auto: %s", exc)

    # ------------------------------------------------------------------
    # PASO 1: Simular la Raspberry Pi publicando lecturas de EMERGENCIA
    # ------------------------------------------------------------------
    logger.info("=" * 60)
    logger.info("PASO 1: Publicar lecturas EMERGENCIA desde 'raspi-01'")
    logger.info("=" * 60)

    readings_before = get_count("/api/sensors/history?limit=500") or 0
    logger.info("Lecturas en MongoDB antes: %d", readings_before)

    mock = MQTTMockProvider(seed=99)
    pub_client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id=f"raspi_simulado_{uuid.uuid4().hex[:8]}",
    )
    pub_client.connect(settings.mqtt_host, settings.mqtt_port, 30)
    pub_client.loop_start()

    # Publicar temperatura alta + gas alto (escenario emergencia)
    high_temp = mock.generate_sensor_reading("temperature", "control", "raspi-sim-e2e")
    high_temp["value"] = 36.5
    high_temp["status"] = "warning"
    publish(pub_client, f"{base}/sensores/temperatura", high_temp)

    high_gas = mock.generate_sensor_reading("gas", "control", "raspi-sim-e2e")
    high_gas["value"] = 800.0
    high_gas["status"] = "critical"
    publish(pub_client, f"{base}/sensores/gas", high_gas)

    time.sleep(3)

    pub_client.loop_stop()
    pub_client.disconnect()

    # Verificar que el backend las recibió
    readings_after = get_count("/api/sensors/history?limit=500") or 0
    added = readings_after - readings_before
    logger.info("Lecturas añadidas: %d", added)
    if added < 1:
        logger.error("❌ El backend no persistió ninguna lectura MQTT")
        return 2

    # Verificar que el estado global cambió a EMERGENCIA
    status = get_status()
    state_ok = assert_eq("Estado global = EMERGENCIA", "EMERGENCIA", status.get("overall_state"))
    fan_ok = assert_eq("Ventilador activo", True, status.get("fan_active"))
    buzzer_ok = assert_eq("Buzzer activo", True, status.get("buzzer_active"))

    # ------------------------------------------------------------------
    # PASO 2: Publicar comando de control (simula MQTTX Web)
    # ------------------------------------------------------------------
    logger.info("=" * 60)
    logger.info("PASO 2: Publicar comando de control desde 'mqttx_e2e'")
    logger.info("=" * 60)

    cmds_before = get_count("/api/commands")
    logger.info("Comandos antes: %d", cmds_before)

    pub_client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id=f"mqttx_e2e_{uuid.uuid4().hex[:8]}",
    )
    pub_client.connect(settings.mqtt_host, settings.mqtt_port, 30)
    pub_client.loop_start()

    payload = {
        "command": "set_pump",
        "target": "pump",
        "source": "mqttx_e2e_test",
        "payload": {"state": "off", "area": "area_2"},
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    publish(pub_client, f"{base}/control/remoto", payload)

    time.sleep(3)

    pub_client.loop_stop()
    pub_client.disconnect()

    cmds_after = get_count("/api/commands")
    added_cmds = cmds_after - cmds_before
    logger.info("Comandos añadidos: %d", added_cmds)
    if added_cmds < 1:
        logger.error("❌ El backend no procesó el comando MQTT")
        return 3

    # ------------------------------------------------------------------
    # PASO 3: Verificar dashboard refleja todo
    # ------------------------------------------------------------------
    logger.info("=" * 60)
    logger.info("PASO 3: Verificar dashboard")
    logger.info("=" * 60)

    dash = get_dashboard()
    events = dash.get("recent_events", [])
    commands = dash.get("recent_commands", [])
    logs = dash.get("recent_logs", [])

    logger.info("Events: %d, Commands: %d, Logs: %d", len(events), len(commands), len(logs))
    if events:
        logger.info("Último evento: %s [%s] - %s",
                    events[0].get("event_type"), events[0].get("severity"), events[0].get("message", "")[:80])
    if commands:
        logger.info("Último comando: %s - source=%s",
                    commands[0].get("command"), commands[0].get("source"))

    # ------------------------------------------------------------------
    # Resultado
    # ------------------------------------------------------------------
    logger.info("=" * 60)
    total_ok = state_ok and fan_ok and buzzer_ok and added >= 1 and added_cmds >= 1
    if total_ok:
        logger.info("✅ FLUJO END-TO-END OK — MQTT → Backend → MongoDB → Dashboard")
        return 0
    else:
        logger.error("❌ FLUJO END-TO-END FALLÓ")
        return 4


if __name__ == "__main__":
    import sys
    sys.exit(main())
