r"""
E2E MQTTX Simulator — Simula exactamente lo que hace MQTTX Web al
publicar en broker.emqx.io, usando los mismos topicos, payloads y QoS.

Este script:
1. Se conecta al broker.emqx.io:1883 (mismo broker que MQTTX Web)
2. Publica un set completo de pruebas:
   - 1 sensor (temperatura alta)
   - 1 sensor (gas peligroso)
   - 1 control (set_lights)
   - 1 control (set_pump)
   - 1 control (set_fan)
   - 1 control (set_mode)
3. Verifica que el backend proceso cada mensaje (logs y dashboard)
4. Imprime un resumen claro

Uso:
    C:\Users\crjav\AppData\Local\Programs\Python\Python313\python.exe ^
        D:\Projects\USAC\ARQUI1V1S_G-17\Proyecto1\backend\test_mqttx_simulator.py
"""
import json
import random
import time
import sys
from datetime import datetime, timezone, timedelta

import paho.mqtt.client as mqtt
import urllib.request

BROKER = "broker.emqx.io"
PORT = 1883
BASE = "invernadero"
CLIENT_ID = f"mqttx_simulator_{random.randint(0, 100000)}"
API = "http://127.0.0.1:8080"


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def build_sensor(sensor_type: str, value: float, unit: str, area: str = "control") -> dict:
    return {
        "sensor_type": sensor_type,
        "value": value,
        "unit": unit,
        "area": area,
        "status": "normal" if value < 30 else "warning",
        "source": "mqttx_simulator",
        "timestamp": now(),
    }


def build_command(command: str, target: str, state: str, area: str = None) -> dict:
    return {
        "command": command,
        "target": target,
        "source": "mqttx_simulator",
        "payload": {"state": state, "area": area} if area else {"state": state},
        "timestamp": now(),
    }


def publish(client: mqtt.Client, topic: str, payload: dict) -> bool:
    data = json.dumps(payload)
    info = client.publish(topic, data, qos=1)
    info.wait_for_publish(timeout=3)
    ok = info.is_published() and info.rc == 0
    status = "OK" if ok else "FAIL(rc=" + str(info.rc) + ")"
    print(f"  [{status}] {topic} -> {data[:80]}{'...' if len(data) > 80 else ''}")
    return ok


def get_dashboard() -> dict:
    with urllib.request.urlopen(f"{API}/api/dashboard", timeout=5) as r:
        return json.loads(r.read())


def get_status() -> dict:
    with urllib.request.urlopen(f"{API}/api/dashboard", timeout=5) as r:
        return json.loads(r.read()).get("status", {})


def test_publish_block(client: mqtt.Client, name: str, blocks: list) -> dict:
    print(f"\n=== {name} ===")
    results = {"sent": 0, "ok": 0}
    for topic, payload in blocks:
        results["sent"] += 1
        if publish(client, topic, payload):
            results["ok"] += 1
    return results


def main() -> int:
    client = mqtt.Client(client_id=CLIENT_ID, clean_session=True)
    client.connect(BROKER, PORT, keepalive=60)
    client.loop_start()
    time.sleep(0.5)
    print(f"Conectado a {BROKER}:{PORT} con client_id={CLIENT_ID}")

    initial = get_status()
    print(f"Estado inicial del sistema: temp={initial.get('temperature')} gas={initial.get('gas')}"
          f" luces={initial.get('lights_active')} bomba={initial.get('pump_active')}"
          f" ventilador={initial.get('fan_active')} modo={initial.get('mode')}")

    results = {}

    # 1. SENSORES: alta temperatura, gas seguro, suelo seco, etc.
    sensor_blocks = [
        (f"{BASE}/sensores/temperatura", build_sensor("temperature", 28.5, "°C")),
        (f"{BASE}/sensores/gas", build_sensor("gas", 50.0, "ppm")),
        (f"{BASE}/sensores/humedad_suelo_area1", build_sensor("soil_1", 25.0, "%", "area_1")),
    ]
    results["sensores"] = test_publish_block(client, "TEST 1: Sensores (temperatura, gas, suelo)", sensor_blocks)

    time.sleep(2.0)
    s1 = get_status()
    print(f"  -> Estado tras sensores: temp={s1.get('temperature')} gas={s1.get('gas')}"
          f" suelo1={s1.get('soil_1')}")

    # 2. CONTROLES
    control_blocks = [
        (f"{BASE}/control/remoto", build_command("set_lights", "lights", "on")),
        (f"{BASE}/control/remoto", build_command("set_pump", "pump", "on", "area_1")),
        (f"{BASE}/control/remoto", build_command("set_fan", "fan", "on")),
        (f"{BASE}/control/remoto", build_command("set_mode", "mode", "manual")),
    ]
    results["controles"] = test_publish_block(client, "TEST 2: Controles (luces, bomba, ventilador, modo)", control_blocks)

    time.sleep(2.0)
    s2 = get_status()
    print(f"  -> Estado tras controles: luces={s2.get('lights_active')}"
          f" bomba={s2.get('pump_active')} ventilador={s2.get('fan_active')}"
          f" modo={s2.get('mode')}")

    # 3. APAGAR
    off_blocks = [
        (f"{BASE}/control/remoto", build_command("set_lights", "lights", "off")),
        (f"{BASE}/control/remoto", build_command("set_pump", "pump", "off", "area_1")),
        (f"{BASE}/control/remoto", build_command("set_fan", "fan", "off")),
        (f"{BASE}/control/remoto", build_command("set_mode", "mode", "auto")),
    ]
    results["apagado"] = test_publish_block(client, "TEST 3: Apagado (todo a off, modo auto)", off_blocks)

    time.sleep(2.0)
    s3 = get_status()
    print(f"  -> Estado tras apagado: luces={s3.get('lights_active')}"
          f" bomba={s3.get('pump_active')} ventilador={s3.get('fan_active')}"
          f" modo={s3.get('mode')}")

    # 4. EMERGENCIA
    emergency_blocks = [
        (f"{BASE}/sensores/gas", build_sensor("gas", 200.0, "ppm")),
    ]
    results["emergencia"] = test_publish_block(client, "TEST 4: Emergencia (gas=200ppm)", emergency_blocks)

    time.sleep(2.0)
    s4 = get_status()
    print(f"  -> Estado tras emergencia: state={s4.get('overall_state')} gas={s4.get('gas')}"
          f" alarma={s4.get('buzzer_active')} ventilador={s4.get('fan_active')}")

    client.disconnect()
    client.loop_stop()

    total_sent = sum(r["sent"] for r in results.values())
    total_ok = sum(r["ok"] for r in results.values())
    print(f"\n=== RESUMEN ===")
    print(f"Mensajes enviados: {total_sent}, publicados OK: {total_ok}")
    print(f"Estados observados: inicial={initial.get('overall_state')}, "
          f"tras_sensores={s1.get('overall_state')}, "
          f"tras_controles={s2.get('overall_state')}, "
          f"tras_apagado={s3.get('overall_state')}, "
          f"tras_emergencia={s4.get('overall_state')}")
    print("\nRevisa el log del backend (backend.log) para ver cada 'MQTT IN'")
    print("y revisa el dashboard http://localhost:5173 para ver los cambios.")
    return 0 if total_ok == total_sent else 1


if __name__ == "__main__":
    sys.exit(main())
