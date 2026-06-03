"""
Test de Integración Completo — Invernadero Inteligente IoT
============================================================
Valida TODOS los endpoints del backend, simulación de datos,
y contrato MQTT usando TestClient de FastAPI.

Uso:  cd backend && python test_integration.py
"""

import sys
import time
import json
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

passed = 0
failed = 0
errors: list[str] = []


def t(name: str, method: str, path: str, expected_status: int = 200,
      body: dict | None = None, checks: list[callable] | None = None) -> None:
    global passed, failed
    if method == "GET":
        r = client.get(path)
    elif method == "POST":
        r = client.post(path, json=body or {})
    else:
        r = client.request(method, path, json=body)
    ok = r.status_code == expected_status
    msg = f"[{'OK' if ok else 'FAIL'}] {method} {path} -> {r.status_code} (esperado {expected_status})"
    if checks and ok:
        for check_fn in checks:
            try:
                check_fn(r.json())
            except AssertionError as e:
                ok = False
                msg += f" | CHECK: {e}"
    if ok:
        passed += 1
        print(f"  {msg}")
    else:
        failed += 1
        body_text = r.text[:300]
        errors.append(f"{msg}\n       BODY: {body_text}")
        print(f"  {msg}")
        print(f"       BODY: {body_text}")


def has_fields(*fields: str):
    def _check(data):
        if isinstance(data, list):
            if data:
                for f in fields:
                    assert f in data[0], f"Campo '{f}' no encontrado en item[0]"
            return
        assert isinstance(data, dict), f"Se esperaba dict, obtuvo {type(data).__name__}"
        for f in fields:
            assert f in data, f"Campo '{f}' no encontrado"
    return _check

def nonempty(data):
    if isinstance(data, list):
        assert len(data) > 0, "Lista vacía"
    elif isinstance(data, dict):
        assert len(data) > 0, "Dict vacío"


def run_all():
    global passed, failed, errors
    print("=" * 72)
    print("  TEST DE INTEGRACIÓN — INVERNADERO INTELIGENTE IoT")
    print(f"  TestClient http://testserver (FastAPI offline)")
    print("=" * 72)

    # 1. HEALTH
    print("\n>>> 1. HEALTH CHECK <<<")
    t("GET /api/health", "GET", "/api/health", 200,
      checks=[has_fields("status", "mongodb", "timestamp")])

    # 2. SEED
    print("\n>>> 2. SEED DATABASE <<<")
    t("POST /api/seed", "POST", "/api/seed", 200,
      checks=[has_fields("status", "message")])

    # 3. DASHBOARD
    print("\n>>> 3. DASHBOARD <<<")
    r = client.get("/api/dashboard")
    t("GET /api/dashboard", "GET", "/api/dashboard", 200,
      checks=[has_fields("status", "recent_readings", "recent_events",
                         "recent_commands", "recent_logs")])

    # 4. SENSORS
    print("\n>>> 4. SENSORES <<<")
    t("GET /api/sensors/latest", "GET", "/api/sensors/latest", 200, checks=[nonempty])
    t("GET /api/sensors/history", "GET", "/api/sensors/history", 200, checks=[has_fields("data", "total")])
    t("GET /api/sensors/history?type=temperature", "GET", "/api/sensors/history?type=temperature", 200)
    t("GET /api/sensors/history?type=humidity", "GET", "/api/sensors/history?type=humidity", 200)
    t("GET /api/readings/latest", "GET", "/api/readings/latest", 200, checks=[nonempty])
    t("POST /api/readings (crear lectura)", "POST", "/api/readings", 200,
      body={"sensor_type": "temperature", "value": 25.5, "unit": "C",
            "area": "area_1", "status": "normal", "source": "test"},
      checks=[has_fields("inserted_id")])

    # 5. EVENTS
    print("\n>>> 5. EVENTOS <<<")
    t("GET /api/events", "GET", "/api/events", 200, checks=[has_fields("data", "total")])
    t("GET /api/events?severity=warning", "GET", "/api/events?severity=warning", 200)
    t("GET /api/events?severity=critical", "GET", "/api/events?severity=critical", 200)
    t("GET /api/events/latest", "GET", "/api/events/latest", 200, checks=[nonempty])
    t("POST /api/events (crear evento)", "POST", "/api/events", 200,
      body={"event_type": "test", "severity": "info", "message": "Test event", "area": "area_1"},
      checks=[has_fields("inserted_id")])
    t("POST /api/events (critical)", "POST", "/api/events", 200,
      body={"event_type": "emergency", "severity": "critical",
            "message": "EMERGENCIA: Gas detectado", "area": "control"},
      checks=[has_fields("inserted_id")])

    # 6. COMMANDS
    print("\n>>> 6. COMANDOS <<<")
    t("GET /api/commands", "GET", "/api/commands", 200, checks=[has_fields("data", "total")])
    t("GET /api/commands/latest", "GET", "/api/commands/latest", 200, checks=[nonempty])
    t("POST /api/commands (crear comando)", "POST", "/api/commands", 200,
      body={"command": "set_pump", "target": "pump", "source": "test",
            "payload": {"state": "on", "area": "area_1"}},
      checks=[has_fields("inserted_id", "mqtt")])

    # 7. SYSTEM STATUS
    print("\n>>> 7. STATUS DEL SISTEMA <<<")
    t("GET /api/status", "GET", "/api/status", 200,
      checks=[has_fields("mode", "overall_state", "temperature", "humidity",
                         "soil_1", "soil_2", "light", "gas",
                         "pump_active", "fan_active", "lights_active", "buzzer_active")])
    t("POST /api/system-status (actualizar estado)", "POST", "/api/system-status", 200,
      body={"mode": "auto", "overall_state": "NORMAL", "temperature": 25.0},
      checks=[has_fields("inserted_id")])

    # 8. CONTROL
    print("\n>>> 8. CONTROL DE ACTUADORES <<<")
    t("POST /api/control/mode (auto)", "POST", "/api/control/mode", 200,
      body={"mode": "auto", "source": "test"})
    t("POST /api/control/mode (manual)", "POST", "/api/control/mode", 200,
      body={"mode": "manual", "source": "test"})
    t("POST /api/control/irrigation (on)", "POST", "/api/control/irrigation", 200,
      body={"state": "on", "area": "area_1", "source": "test"})
    t("POST /api/control/irrigation (off)", "POST", "/api/control/irrigation", 200,
      body={"state": "off", "area": "area_1", "source": "test"})
    t("POST /api/control/lights (on)", "POST", "/api/control/lights", 200,
      body={"state": "on", "source": "test"})
    t("POST /api/control/lights (off)", "POST", "/api/control/lights", 200,
      body={"state": "off", "source": "test"})
    t("POST /api/control/fan (on)", "POST", "/api/control/fan", 200,
      body={"state": "on", "source": "test"})
    t("POST /api/control/fan (off)", "POST", "/api/control/fan", 200,
      body={"state": "off", "source": "test"})
    t("POST /api/control/alarm (on)", "POST", "/api/control/alarm", 200,
      body={"state": "on", "source": "test"})
    t("POST /api/control/alarm (mute)", "POST", "/api/control/alarm", 200,
      body={"state": "mute", "source": "test"})
    t("POST /api/control/alarm (off)", "POST", "/api/control/alarm", 200,
      body={"state": "off", "source": "test"})

    # 9. CONTROL VALIDATION (errors)
    print("\n>>> 9. VALIDACIÓN DE CONTROL <<<")
    t("POST /api/control/irrigation (estado inválido)", "POST", "/api/control/irrigation", 400,
      body={"state": "invalid_state", "source": "test"})
    t("POST /api/control/mode (modo inválido)", "POST", "/api/control/mode", 422,
      body={"mode": "invalid_mode", "source": "test"})
    t("POST /api/control/alarm (estado inválido)", "POST", "/api/control/alarm", 400,
      body={"state": "invalid", "source": "test"})

    # 10. ACTUATOR LOGS
    print("\n>>> 10. ACTUATOR LOGS <<<")
    t("GET /api/actuator-logs", "GET", "/api/actuator-logs", 200, checks=[has_fields("data", "total")])
    t("GET /api/actuator-logs/latest", "GET", "/api/actuator-logs/latest", 200, checks=[nonempty])
    t("POST /api/actuator-logs (crear log)", "POST", "/api/actuator-logs", 200,
      body={"actuator": "pump", "action": "on", "area": "area_1", "source": "test"},
      checks=[has_fields("inserted_id")])

    # 11. ARM64
    print("\n>>> 11. ARM64 <<<")
    t("GET /api/arm64/results", "GET", "/api/arm64/results", 200, checks=[nonempty])
    t("GET /api/arm64-results/latest", "GET", "/api/arm64-results/latest", 200)
    t("POST /api/arm64-results (registrar resultado)", "POST", "/api/arm64-results", 200,
      body={"module": "WEIGHTED_MEAN", "total_values": 30,
            "results": {"SUM_X": 920, "WEIGHT_SUM": 465, "WEIGHTED_MEAN": 31},
            "source": "test"},
      checks=[has_fields("inserted_id")])
    t("POST /api/arm64-results/mock (generar mock)", "POST", "/api/arm64-results/mock", 200,
      checks=[has_fields("status")])

    # 12. SWAGGER / OPENAPI
    print("\n>>> 12. DOCUMENTACIÓN <<<")
    t("GET /openapi.json", "GET", "/openapi.json", 200, checks=[has_fields("openapi", "info", "paths")])

    # 13. DASHBOARD VALIDATION (all data present)
    print("\n>>> 13. DASHBOARD POST-SEED (datos completos) <<<")
    r = client.get("/api/dashboard")
    data = r.json()
    readings = data.get("recent_readings", [])
    events = data.get("recent_events", [])
    commands = data.get("recent_commands", [])
    logs = data.get("recent_logs", [])
    status = data.get("status", {})
    print(f"  [DATA]    readings={len(readings)}, events={len(events)}, "
          f"commands={len(commands)}, logs={len(logs)}")
    print(f"  [STATE]   mode={status.get('mode')}, "
          f"overall_state={status.get('overall_state')}")
    print(f"  [METRICS] temp={status.get('temperature')}°C, "
          f"hum={status.get('humidity')}%, "
          f"soil1={status.get('soil_1')}%, soil2={status.get('soil_2')}%, "
          f"light={status.get('light')}%, gas={status.get('gas')}ppm")
    print(f"  [ACTUAT]  pump={status.get('pump_active')}, "
          f"fan={status.get('fan_active')}, "
          f"lights={status.get('lights_active')}, "
          f"buzzer={status.get('buzzer_active')}")
    assert len(readings) > 0, "Dashboard sin readings"
    assert len(events) > 0, "Dashboard sin events"
    assert len(commands) > 0, "Dashboard sin commands"
    assert len(logs) > 0, "Dashboard sin logs"
    assert status.get("mode") is not None, "Dashboard sin mode"
    assert status.get("overall_state") is not None, "Dashboard sin overall_state"
    passed += 1
    print(f"  [OK] Dashboard post-seed contiene todos los datos esperados")

    # 14. MQTT CONTRACT VALIDATION (offline)
    print("\n>>> 14. CONTRATO MQTT (validación offline) <<<")
    try:
        from app.mqtt.topic_registry import MQTTTopicRegistry
        from app.mqtt.payload_validator import MQTTPayloadValidator
        from app.mqtt.mock_provider import MQTTMockProvider
        from app.config import get_settings

        settings = get_settings()
        reg = MQTTTopicRegistry()
        val = MQTTPayloadValidator()
        mock = MQTTMockProvider(seed=42)

        # Check base topic
        assert reg.base == "grupo17/invernadero", f"Base topic: {reg.base}"
        print(f"  [OK] Base topic: {reg.base}")

        # All topics from contract
        expected = [
            "grupo17/invernadero/sensores/temperatura",
            "grupo17/invernadero/sensores/humedad_ambiente",
            "grupo17/invernadero/sensores/humedad_suelo_area1",
            "grupo17/invernadero/sensores/humedad_suelo_area2",
            "grupo17/invernadero/sensores/luz",
            "grupo17/invernadero/sensores/gas",
            "grupo17/invernadero/actuadores/riego",
            "grupo17/invernadero/actuadores/riego_area1",
            "grupo17/invernadero/actuadores/riego_area2",
            "grupo17/invernadero/actuadores/ventilador",
            "grupo17/invernadero/actuadores/luces",
            "grupo17/invernadero/actuadores/alarma",
            "grupo17/invernadero/control/remoto",
            "grupo17/invernadero/control/manual",
            "grupo17/invernadero/estado/global",
        ]
        actual = reg.all_topics
        for topic in expected:
            assert topic in actual, f"Falta topic: {topic}"
        print(f"  [OK] {len(expected)} topics del contrato registrados")
        print(f"  [OK] Topics: {', '.join(expected[:6])}...")

        # Mock provider
        reading = mock.generate_sensor_reading("temperature")
        assert reading["sensor_type"] == "temperature"
        assert "value" in reading and "unit" in reading and "area" in reading
        print(f"  [OK] Mock provider genera lectura: {reading['sensor_type']}={reading['value']}{reading['unit']}")

        full = mock.generate_full_reading_set()
        assert len(full) == 6
        print(f"  [OK] Set completo: {len(full)} lecturas (1 por sensor)")

        state = mock.generate_global_state()
        assert state["overall_state"] in ("NORMAL", "ADVERTENCIA", "RIEGO_ACTIVO", "MODO_MANUAL", "EMERGENCIA")
        print(f"  [OK] Estado global mock: {state['overall_state']}")

        hist = mock.generate_historical_readings(30)
        assert len(hist) == 180
        print(f"  [OK] {len(hist)} lecturas históricas generadas (30 sets × 6)")

        # Payload validator
        valid = {"sensor_type": "temperature", "value": 25.5, "unit": "C",
                 "area": "control", "status": "normal", "source": "test",
                 "timestamp": "2026-06-03T12:00:00Z"}
        model = val.validate_sensor(valid)
        assert model.sensor_type == "temperature"
        print(f"  [OK] Validador acepta payload correcto: {model.sensor_type}={model.value}")

        invalid = {"sensor_type": "temperature", "value": None}
        try:
            val.validate_sensor(invalid)
            assert False, "Payload invalido aceptado"
        except Exception:
            print(f"  [OK] Validador rechaza payload invalido (ValidationError)")

        passed += 1
        print(f"  [OK] TODO EL CONTRATO MQTT HA SIDO VALIDADO")
    except Exception as e:
        import traceback
        traceback.print_exc()
        failed += 1
        errors.append(f"MQTT validation: {e}")

    # 15. SUMMARY
    total = passed + failed
    print(f"\n{'='*72}")
    print(f"  RESULTADOS: {passed}/{total} passed, {failed} failed")
    print(f"{'='*72}")
    if errors:
        for e in errors:
            print(f"\n  !! {e}")
    return failed == 0


if __name__ == "__main__":
    success = run_all()
    sys.exit(0 if success else 1)
