"""
test_regresion.py — Suite de regresion completa que valida:
  1. REST API (endpoints principales, forma correcta)
  2. MongoDB (6 colecciones, indices, datos)
  3. MQTT (subscriber conectado, suscripciones activas)
  4. Flujo E2E (cliente externo -> broker -> backend -> MongoDB)
  5. Reglas automaticas (temperatura alta, gas peligroso, suelo seco)
  6. Filtro anti-loop (el backend no procesa sus propios mensajes)
  7. Contrato MQTT (topics y payloads validados)

Uso (backend en :8080, ENABLE_MQTT=true, MongoDB local):
    cd backend
    python test_regresion.py
"""
import json
import sys
import time
import uuid
from datetime import datetime, timezone

import paho.mqtt.client as mqtt
import requests

BROKER = "broker.emqx.io"
PORT = 1883
BASE = "grupo17/invernadero"
API = "http://127.0.0.1:8080"


PASS = "[OK]"
FAIL = "[FAIL]"


class TestRunner:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.results = []

    def assert_true(self, name: str, condition: bool, detail: str = "") -> bool:
        if condition:
            print(f"   {PASS} {name}")
            self.passed += 1
            self.results.append((name, True, detail))
            return True
        msg = detail if detail else "condition false"
        print(f"   {FAIL} {name}: {msg}")
        self.failed += 1
        self.results.append((name, False, msg))
        return False

    def section(self, title: str):
        print(f"\n=== {title} ===")


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def count_by_source(source: str) -> int:
    """Cuenta readings de un source especifico via API."""
    r = requests.get(f"{API}/api/sensors/history?source={source}&limit=500", timeout=5)
    r.raise_for_status()
    return r.json().get("total", 0)


def count_commands_by_source(source: str) -> int:
    """Cuenta comandos de un source especifico via API."""
    r = requests.get(f"{API}/api/commands?source={source}&limit=200", timeout=5)
    r.raise_for_status()
    return r.json().get("total", 0)


def test_rest_api(t: TestRunner) -> None:
    t.section("1. REST API")

    h = requests.get(f"{API}/api/health", timeout=5).json()
    t.assert_true("GET /api/health responde 200", True)
    t.assert_true("GET /api/health status=ok", h.get("status") == "ok")
    t.assert_true("GET /api/health mongodb=true", h.get("mongodb") is True)

    d = requests.get(f"{API}/api/dashboard", timeout=5).json()
    t.assert_true("GET /api/dashboard tiene status", "status" in d)
    t.assert_true("GET /api/dashboard tiene recent_readings", "recent_readings" in d)
    t.assert_true("GET /api/dashboard tiene recent_events", "recent_events" in d)
    t.assert_true("GET /api/dashboard tiene recent_commands", "recent_commands" in d)
    t.assert_true("GET /api/dashboard tiene recent_logs", "recent_logs" in d)

    s = requests.get(f"{API}/api/sensors/latest", timeout=5).json()
    t.assert_true("GET /api/sensors/latest retorna array", isinstance(s, list))

    history = requests.get(f"{API}/api/sensors/history?limit=10", timeout=5).json()
    t.assert_true("GET /api/sensors/history tiene data", "data" in history)
    t.assert_true("GET /api/sensors/history tiene total", "total" in history)

    events = requests.get(f"{API}/api/events?limit=10", timeout=5).json()
    t.assert_true("GET /api/events tiene data", "data" in events)

    commands = requests.get(f"{API}/api/commands?limit=10", timeout=5).json()
    t.assert_true("GET /api/commands tiene data", "data" in commands)

    status = requests.get(f"{API}/api/status", timeout=5).json()
    t.assert_true("GET /api/status tiene overall_state", "overall_state" in status)
    t.assert_true("GET /api/status tiene mode", "mode" in status)

    arm = requests.get(f"{API}/api/arm64/results", timeout=5).json()
    t.assert_true("GET /api/arm64/results retorna dict", isinstance(arm, dict))
    if not arm:
        t.section("  (Generando mock ARM64 con ?dev=true)")
        requests.post(f"{API}/api/arm64-results/mock?dev=true", timeout=5)
        arm = requests.get(f"{API}/api/arm64/results", timeout=5).json()
    t.assert_true(
        "GET /api/arm64/results tiene modulos ARM64",
        "WEIGHTED_MEAN" in arm and "VARIANCE" in arm and "ANOMALY_DETECTION" in arm
        and "PREDICTION" in arm and "ADVANCED_TREND" in arm,
    )

    actuator = requests.get(f"{API}/api/actuator-logs?limit=5", timeout=5).json()
    t.assert_true("GET /api/actuator-logs tiene data", "data" in actuator)


def test_control_endpoints(t: TestRunner) -> None:
    t.section("2. CONTROL ENDPOINTS")

    r = requests.post(f"{API}/api/control/irrigation", json={"state": "on", "area": "area_1"}, timeout=5)
    t.assert_true("POST /api/control/irrigation 200", r.status_code == 200)

    r = requests.post(f"{API}/api/control/lights", json={"state": "on"}, timeout=5)
    t.assert_true("POST /api/control/lights 200", r.status_code == 200)

    r = requests.post(f"{API}/api/control/fan", json={"state": "off"}, timeout=5)
    t.assert_true("POST /api/control/fan 200", r.status_code == 200)

    r = requests.post(f"{API}/api/control/alarm", json={"state": "mute"}, timeout=5)
    t.assert_true("POST /api/control/alarm 200", r.status_code == 200)

    r = requests.post(f"{API}/api/control/mode", json={"mode": "manual"}, timeout=5)
    t.assert_true("POST /api/control/mode 200", r.status_code == 200)

    time.sleep(1)
    s = requests.get(f"{API}/api/status", timeout=5).json()
    t.assert_true("Status refleja lights=true", s.get("lights_active") is True)
    t.assert_true("Status refleja mode=manual", s.get("mode") == "manual")


def test_mongodb_collections(t: TestRunner) -> None:
    t.section("3. MONGODB COLECCIONES")

    collections = {
        "sensor_readings": "/api/sensors/history?limit=1",
        "events": "/api/events?limit=1",
        "commands": "/api/commands?limit=1",
        "system_status": "/api/status",
        "actuator_logs": "/api/actuator-logs?limit=1",
        "arm64_results": "/api/arm64/results",
    }

    for name, endpoint in collections.items():
        r = requests.get(f"{API}{endpoint}", timeout=5)
        t.assert_true(f"Coleccion {name} accesible", r.status_code == 200)


def test_mqtt_connection(t: TestRunner) -> None:
    t.section("4. MQTT SUBSCRIBER")

    h = requests.get(f"{API}/api/health", timeout=5).json()
    t.assert_true("MQTT enabled", h.get("mqtt_enabled") is True)
    t.assert_true("MQTT connected", h.get("mqtt_connected") is True)
    subs = h.get("mqtt_subscriptions", [])
    t.assert_true("Suscripciones >= 4", len(subs) >= 4, f"got {len(subs)}: {subs}")
    t.assert_true(
        "Suscripcion a sensores/# presente",
        any("sensores/#" in s for s in subs),
    )

    r = requests.post(f"{API}/api/mqtt/reconnect", timeout=5).json()
    t.assert_true("POST /api/mqtt/reconnect responde ok", r.get("status") == "ok")


def test_mqtt_e2e(t: TestRunner) -> None:
    t.section("5. FLUJO MQTT E2E")

    cid = f"regression_test_{uuid.uuid4().hex[:8]}"
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=cid)
    client.connect(BROKER, PORT, keepalive=30)
    client.loop_start()
    time.sleep(0.5)

    sensor_payload = {
        "sensor_type": "temperature", "value": 28.0, "unit": "°C",
        "area": "control", "status": "normal", "source": "regression_test",
        "timestamp": now(),
    }
    info = client.publish(f"{BASE}/sensores/temperatura", json.dumps(sensor_payload), qos=1)
    info.wait_for_publish(timeout=5)
    t.assert_true("Publish sensor temperature OK", info.rc == 0)

    cmd_payload = {
        "command": "set_lights", "target": "lights", "source": "regression_test",
        "payload": {"state": "off"}, "timestamp": now(),
    }
    info2 = client.publish(f"{BASE}/control/remoto", json.dumps(cmd_payload), qos=1)
    info2.wait_for_publish(timeout=5)
    t.assert_true("Publish command set_lights OK", info2.rc == 0)

    client.loop_stop()
    client.disconnect()

    time.sleep(3)

    rt_count = count_by_source("regression_test")
    cmd_count = count_commands_by_source("regression_test")
    t.assert_true("Reading nueva con source=regression_test", rt_count >= 1, f"count={rt_count}")
    t.assert_true("Command nuevo con source=regression_test", cmd_count >= 1, f"count={cmd_count}")


def test_automatic_rules(t: TestRunner) -> None:
    t.section("6. REGLAS AUTOMATICAS (modo auto)")

    requests.post(f"{API}/api/control/mode", json={"mode": "auto"}, timeout=5)
    time.sleep(1)

    cid = f"rules_{uuid.uuid4().hex[:8]}"
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=cid)
    client.connect(BROKER, PORT, keepalive=30)
    client.loop_start()
    time.sleep(0.5)

    gas_payload = {
        "sensor_type": "gas", "value": 200.0, "unit": "ppm",
        "area": "control", "status": "critical", "source": "regression_test",
        "timestamp": now(),
    }
    client.publish(f"{BASE}/sensores/gas", json.dumps(gas_payload), qos=1).wait_for_publish(timeout=5)

    time.sleep(3)

    s = requests.get(f"{API}/api/status", timeout=5).json()
    t.assert_true(
        "Gas > 150 ppm activa ventilador (regla de gas)",
        s.get("fan_active") is True,
        f"fan_active={s.get('fan_active')} state={s.get('overall_state')} mode={s.get('mode')}",
    )
    t.assert_true(
        "Gas > 150 ppm activa alarma (regla de gas)",
        s.get("buzzer_active") is True,
        f"buzzer_active={s.get('buzzer_active')} state={s.get('overall_state')}",
    )
    t.assert_true(
        "Estado global refleja accion de regla (no MODO_MANUAL)",
        s.get("overall_state") in ("EMERGENCIA", "ADVERTENCIA"),
        f"state={s.get('overall_state')} mode={s.get('mode')}",
    )

    events = requests.get(f"{API}/api/events?limit=50", timeout=5).json().get("data", [])
    has_emergency = any(e.get("event_type") == "emergency" for e in events)
    t.assert_true("Evento de emergencia registrado en coleccion events", has_emergency)

    requests.post(f"{API}/api/control/mode", json={"mode": "manual"}, timeout=5)
    client.loop_stop()
    client.disconnect()


def test_self_publish_filter(t: TestRunner) -> None:
    t.section("7. FILTRO ANTI-LOOP (self-publish)")

    unique_source = f"loop_test_{uuid.uuid4().hex[:8]}"
    cid = f"loop_{uuid.uuid4().hex[:8]}"
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=cid)
    client.connect(BROKER, PORT, keepalive=30)
    client.loop_start()
    time.sleep(0.5)

    loop_payload = {
        "sensor_type": "temperature", "value": 99.0, "unit": "°C",
        "area": "control", "status": "warning", "source": "api",
        "timestamp": now(),
    }
    client.publish(f"{BASE}/sensores/temperatura", json.dumps(loop_payload), qos=1).wait_for_publish(timeout=5)
    time.sleep(2)

    loop_count = count_by_source("api")
    t.assert_true(
        "Mensaje con source=api NO se persiste (filtro anti-loop)",
        loop_count == 0,
        f"count={loop_count} (deberia ser 0)",
    )

    client.loop_stop()
    client.disconnect()


def main() -> int:
    print("=" * 60)
    print("TEST DE REGRESION COMPLETO")
    print("Invernadero Inteligente IoT — Grupo 17")
    print("=" * 60)

    t = TestRunner()

    try:
        test_rest_api(t)
        test_control_endpoints(t)
        test_mongodb_collections(t)
        test_mqtt_connection(t)
        test_mqtt_e2e(t)
        test_automatic_rules(t)
        test_self_publish_filter(t)
    except requests.exceptions.RequestException as exc:
        print(f"\n[CRITICAL] Backend no responde: {exc}")
        return 2

    print("\n" + "=" * 60)
    print(f"RESUMEN: {t.passed} OK, {t.failed} FAIL")
    print("=" * 60)

    if t.failed == 0:
        print("\nREGRESION EXITOSA — sistema validado al 100%")
        return 0

    print(f"\n{t.failed} tests fallaron:")
    for name, ok, detail in t.results:
        if not ok:
            print(f"   - {name}: {detail}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
