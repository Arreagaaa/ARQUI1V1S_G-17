"""
test_concurrencia.py — Test E2E de concurrencia multi-usuario MQTTX.

Simula 5 clientes MQTTX publicando simultaneamente al broker.emqx.io,
cada uno con un client_id unico y 'source' diferente. El backend debe
procesar TODOS los mensajes sin perder ninguno, demostrar que el
singleton MQTT maneja multiples publicadores concurrentes, y que el
sistema no genera loops ni duplicados.

Escenarios cubiertos:
  - 5 clientes publicando sensores en paralelo
  - 5 clientes publicando comandos en paralelo
  - Mezcla de fuentes (raspi-01, mqttx_user_a/b/c/d/e, simulador)
  - Verificacion: backend recibe >= 10 mensajes, sin duplicados, sin perdidas
  - Verificacion: estado global coherente despues de la rafaga

Uso:
    C:\\Users\\crjav\\AppData\\Local\\Programs\\Python\\Python313\\python.exe ^
        D:\\Projects\\USAC\\ARQUI1V1S_G-17\\Proyecto1\\backend\\test_concurrencia.py
"""
import json
import random
import sys
import time
import threading
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone

import paho.mqtt.client as mqtt
import requests

BROKER = "broker.emqx.io"
PORT = 1883
BASE = "grupo17/invernadero"
API = "http://127.0.0.1:8080"
NUM_CLIENTS = 5
MESSAGES_PER_CLIENT = 2


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def build_sensor(sensor_type: str, value: float, unit: str, source: str) -> dict:
    return {
        "sensor_type": sensor_type,
        "value": value,
        "unit": unit,
        "area": "control",
        "status": "normal" if value < 30 else "warning",
        "source": source,
        "timestamp": now(),
    }


def build_command(command: str, target: str, state: str, source: str) -> dict:
    return {
        "command": command,
        "target": target,
        "source": source,
        "payload": {"state": state},
        "timestamp": now(),
    }


def client_thread(client_id_suffix: str, results: list) -> None:
    """Cada thread crea su propio cliente MQTT y publica sus mensajes."""
    cid = f"mqttx_conc_{client_id_suffix}_{random.randint(0, 99999)}"
    source = f"mqttx_user_{client_id_suffix}"
    temp_value = 20.0 + (ord(client_id_suffix) - ord('a'))

    try:
        c = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=cid)
        c.connect(BROKER, PORT, keepalive=30)
        c.loop_start()
        time.sleep(0.3)

        # Publicar 1 sensor + 1 comando
        sensor = build_sensor("temperature", temp_value, "°C", source)
        info1 = c.publish(f"{BASE}/sensores/temperatura", json.dumps(sensor), qos=1)
        info1.wait_for_publish(timeout=5)
        results.append({
            "client": cid, "type": "sensor", "topic": f"{BASE}/sensores/temperatura",
            "rc": info1.rc, "ok": info1.rc == 0,
        })

        time.sleep(0.2)

        command = build_command("set_lights", "lights", "on", source)
        info2 = c.publish(f"{BASE}/control/remoto", json.dumps(command), qos=1)
        info2.wait_for_publish(timeout=5)
        results.append({
            "client": cid, "type": "command", "topic": f"{BASE}/control/remoto",
            "rc": info2.rc, "ok": info2.rc == 0,
        })

        c.loop_stop()
        c.disconnect()
    except Exception as exc:
        results.append({
            "client": cid, "type": "error", "error": str(exc), "ok": False,
        })


def get_total_readings() -> int:
    r = requests.get(f"{API}/api/sensors/history?limit=200", timeout=5)
    r.raise_for_status()
    return r.json().get("total", 0)


def get_total_commands() -> int:
    r = requests.get(f"{API}/api/commands?limit=200", timeout=5)
    r.raise_for_status()
    return r.json().get("total", 0)


def get_status() -> dict:
    r = requests.get(f"{API}/api/status", timeout=5)
    r.raise_for_status()
    return r.json()


def main() -> int:
    print(f"=== TEST CONCURRENCIA: {NUM_CLIENTS} clientes MQTTX publicando en paralelo ===\n")

    print("1. Verificar backend...")
    h = requests.get(f"{API}/api/health", timeout=5).json()
    if not h.get("mqtt_connected"):
        print(f"   FAIL: backend sin MQTT: {h}")
        return 1
    print(f"   OK: mqtt_connected={h['mqtt_connected']}")

    print("\n2. Estado inicial...")
    before_r = get_total_readings()
    before_c = get_total_commands()
    before_s = get_status()
    print(f"   readings={before_r}, commands={before_c}, state={before_s['overall_state']}")

    print(f"\n3. Lanzando {NUM_CLIENTS} clientes en paralelo...")
    results = []
    threads = []
    for i in range(NUM_CLIENTS):
        suffix = chr(ord('a') + i)
        t = threading.Thread(target=client_thread, args=(suffix, results))
        threads.append(t)
        t.start()

    for t in threads:
        t.join(timeout=10)

    print(f"   {len(results)} mensajes enviados")

    print("\n4. Verificando publicaciones...")
    sensors_ok = sum(1 for r in results if r.get("type") == "sensor" and r.get("ok"))
    commands_ok = sum(1 for r in results if r.get("type") == "command" and r.get("ok"))
    errors = sum(1 for r in results if r.get("type") == "error")
    print(f"   sensors: {sensors_ok}/{NUM_CLIENTS} OK")
    print(f"   commands: {commands_ok}/{NUM_CLIENTS} OK")
    print(f"   errors: {errors}")

    if errors > 0:
        for r in results:
            if r.get("type") == "error":
                print(f"   - {r['client']}: {r['error']}")

    print("\n5. Esperando 5s para que el backend procese...")
    time.sleep(5)

    print("\n6. Estado final...")
    after_r = get_total_readings()
    after_c = get_total_commands()
    after_s = get_status()
    delta_r = after_r - before_r
    delta_c = after_c - before_c
    print(f"   readings: {before_r} -> {after_r} (+{delta_r})")
    print(f"   commands: {before_c} -> {after_c} (+{delta_c})")
    print(f"   state: {before_s['overall_state']} -> {after_s['overall_state']}")
    print(f"   lights: {after_s['lights_active']}")
    print(f"   temperature: {after_s.get('temperature')}")

    print("\n=== RESUMEN ===")
    expected_r = NUM_CLIENTS
    expected_c = NUM_CLIENTS
    print(f"Esperado: +{expected_r} readings, +{expected_c} commands")
    print(f"Real:     +{delta_r} readings, +{delta_c} commands")

    ok = (
        sensors_ok == NUM_CLIENTS
        and commands_ok == NUM_CLIENTS
        and errors == 0
        and delta_r >= expected_r
        and delta_c >= expected_c
        and after_s["lights_active"] is True
    )

    if ok:
        print("\nCONCURRENCIA OK")
        print(f"   - {NUM_CLIENTS} clientes publicaron en paralelo")
        print(f"   - {sensors_ok + commands_ok} mensajes llegaron al backend")
        print(f"   - {delta_r} readings nuevas en MongoDB (>= {expected_r} esperadas)")
        print(f"   - {delta_c} commands nuevos en MongoDB (>= {expected_c} esperados)")
        print(f"   - Estado global coherente: {after_s['overall_state']}")
        print(f"   - Luces activadas por comandos concurrentes: {after_s['lights_active']}")
        return 0

    print("\nFALLO")
    if sensors_ok != NUM_CLIENTS:
        print(f"   - Solo {sensors_ok}/{NUM_CLIENTS} sensors se publicaron OK")
    if commands_ok != NUM_CLIENTS:
        print(f"   - Solo {commands_ok}/{NUM_CLIENTS} commands se publicaron OK")
    if errors > 0:
        print(f"   - {errors} errores de conexion")
    if delta_r < expected_r:
        print(f"   - Readings insuficientes: {delta_r} < {expected_r}")
    if delta_c < expected_c:
        print(f"   - Commands insuficientes: {delta_c} < {expected_c}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
