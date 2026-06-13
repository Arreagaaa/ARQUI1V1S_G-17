import logging
from datetime import datetime, timezone, timedelta

from ..db import get_database
from ..mqtt.publisher import MQTTPublisher

logger = logging.getLogger(__name__)

PUMP_MAX_DURATION_SECONDS = 30
PUMP_MIN_PAUSE_SECONDS = 15

SENSOR_KEY_MAP = {
    "temperature": "temperature",
    "temperatura": "temperature",
    "humidity": "humidity",
    "humedad": "humidity",
    "humedad_ambiente": "humidity",
    "soil_1": "soil_1",
    "soil_2": "soil_2",
    "humidity_soil_1": "soil_1",
    "humidity_soil_2": "soil_2",
    "humedad_suelo_area1": "soil_1",
    "humedad_suelo_area2": "soil_2",
    "light": "light",
    "luz": "light",
    "gas": "gas",
}

DEFAULT_STATUS = {
    "mode": "auto",
    "overall_state": "NORMAL",
    "irrigation_state": "RIEGO_OFF",
    "ventilation_state": "VENTILACION_OFF",
    "gas_state": "GAS_NORMAL",
    "temperature": 0.0,
    "humidity": 0.0,
    "soil_1": 0.0,
    "soil_2": 0.0,
    "light": 0.0,
    "gas": 0.0,
    "pump_active": False,
    "fan_active": False,
    "lights_active": False,
    "buzzer_active": False,
    "pump_started_at": None,
    "pump_last_stopped_at": None,
    "source": "api",
}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def update_system_status(updates: dict) -> dict:
    db = get_database()
    latest = db.system_status.find_one(sort=[("updated_at", -1)])

    if latest:
        new_status = dict(latest)
        new_status.pop("_id", None)
        new_status.update(updates)
        new_status["updated_at"] = _now()
    else:
        new_status = dict(DEFAULT_STATUS)
        new_status.update(updates)
        new_status["updated_at"] = _now()

    # Re-leer modo desde el registro más reciente para evitar que datos
    # obsoletos (race condition con process_reading) reviertan el modo.
    current = db.system_status.find_one(sort=[("updated_at", -1)])
    if current and current.get("mode") in ("auto", "manual"):
        new_status["mode"] = current["mode"]

    new_status["source"] = "api"
    db.system_status.insert_one(new_status)

    try:
        MQTTPublisher().publish_global_state(new_status)
    except Exception as exc:
        logger.debug("Publicación de estado global MQTT omitida: %s", exc)

    return new_status


def process_reading(document: dict) -> dict:
    db = get_database()
    sensor_type = document.get("sensor_type", "").lower()
    value = document.get("value", 0.0)

    status_key = SENSOR_KEY_MAP.get(sensor_type)
    if not status_key:
        return document

    latest = db.system_status.find_one(sort=[("updated_at", -1)])

    temp = value if status_key == "temperature" else (latest.get("temperature", 0.0) if latest else 0.0)
    hum = value if status_key == "humidity" else (latest.get("humidity", 0.0) if latest else 0.0)
    soil1 = value if status_key == "soil_1" else (latest.get("soil_1", 0.0) if latest else 0.0)
    soil2 = value if status_key == "soil_2" else (latest.get("soil_2", 0.0) if latest else 0.0)
    light_val = value if status_key == "light" else (latest.get("light", 0.0) if latest else 0.0)
    gas_val = value if status_key == "gas" else (latest.get("gas", 0.0) if latest else 0.0)

    mode = latest.get("mode", "auto") if latest else "auto"
    updates = {status_key: value}

    if mode == "auto":
        _apply_automation_rules(db, updates, latest, temp, hum, soil1, soil2, light_val, gas_val)
    else:
        updates["overall_state"] = "MODO_MANUAL"
        logger.info("DEBUG mode=%s sensor=%s temp=%.1f gas=%.1f mode=%s",
                     mode, sensor_type, temp, gas_val, mode)

    _enforce_pump_limits(db, updates, latest)
    update_system_status(updates)
    return document


def _enforce_pump_limits(db, updates: dict, latest: dict | None) -> None:
    now = _now()
    pump_active = updates.get("pump_active", latest.get("pump_active", False) if latest else False)
    pump_started_at = latest.get("pump_started_at") if latest else None
    pump_last_stopped_at = latest.get("pump_last_stopped_at") if latest else None

    if pump_active and pump_started_at:
        if isinstance(pump_started_at, str):
            pump_started_at = datetime.fromisoformat(pump_started_at.replace("Z", "+00:00"))
        elapsed = (now - pump_started_at).total_seconds()
        if elapsed >= PUMP_MAX_DURATION_SECONDS:
            updates["pump_active"] = False
            updates["pump_started_at"] = None
            updates["pump_last_stopped_at"] = now.isoformat()
            updates["irrigation_state"] = "RIEGO_OFF"
            if updates.get("overall_state") == "RIEGO_ACTIVO":
                updates["overall_state"] = "NORMAL"
            db.events.insert_one({
                "event_type": "pump_timeout",
                "message": f"Bomba apagada por tiempo máximo ({PUMP_MAX_DURATION_SECONDS}s).",
                "severity": "info",
                "area": "control",
                "source": "backend_rules",
                "created_at": now,
            })
            logger.info("Bomba apagada por tiempo máximo (%ds)", PUMP_MAX_DURATION_SECONDS)

    if not pump_active and pump_last_stopped_at:
        if isinstance(pump_last_stopped_at, str):
            pump_last_stopped_at = datetime.fromisoformat(pump_last_stopped_at.replace("Z", "+00:00"))
        elapsed_since_stop = (now - pump_last_stopped_at).total_seconds()
        if elapsed_since_stop < PUMP_MIN_PAUSE_SECONDS:
            updates["_pump_blocked_until"] = (pump_last_stopped_at + timedelta(seconds=PUMP_MIN_PAUSE_SECONDS)).isoformat()


def _apply_automation_rules(db, updates: dict, latest: dict | None,
                            temp: float, hum: float, soil1: float, soil2: float,
                            light_val: float, gas_val: float) -> None:
    now = _now()
    prev_overall = latest.get("overall_state", "NORMAL") if latest else "NORMAL"
    prev_irrigation = latest.get("irrigation_state", "RIEGO_OFF") if latest else "RIEGO_OFF"
    prev_ventilation = latest.get("ventilation_state", "VENTILACION_OFF") if latest else "VENTILACION_OFF"
    prev_gas = latest.get("gas_state", "GAS_NORMAL") if latest else "GAS_NORMAL"
    prev_pump = latest.get("pump_active", False) if latest else False

    if gas_val > 90.0:
        updates["overall_state"] = "EMERGENCIA"
        updates["gas_state"] = "GAS_EMERGENCIA"
        updates["ventilation_state"] = "VENTILACION_EMERGENCIA"
        updates["fan_active"] = True
        updates["buzzer_active"] = True
        if prev_overall != "EMERGENCIA":
            publisher = MQTTPublisher()
            publisher.publish_control_command(command="set_fan", target="fan", state="on", source="automation")
            publisher.publish_control_command(command="set_buzzer", target="buzzer", state="on", source="automation")
            db.events.insert_one({
                "event_type": "emergency",
                "message": f"EMERGENCIA: Gas detectado por encima del límite seguro ({gas_val:.1f} ppm). Alarma y ventilación activadas.",
                "severity": "critical",
                "area": "control",
                "source": "backend_rules",
                "created_at": now,
            })
            logger.warning("EMERGENCIA: Gas = %.1f ppm", gas_val)
    elif gas_val > 60.0:
        updates["overall_state"] = "ADVERTENCIA"
        updates["gas_state"] = "GAS_ADVERTENCIA"
        updates["fan_active"] = True
        publisher = MQTTPublisher()
        if prev_gas == "GAS_EMERGENCIA":
            publisher.publish_control_command(command="set_buzzer", target="buzzer", state="off", source="automation")
        if prev_gas != "GAS_ADVERTENCIA" and prev_gas != "GAS_EMERGENCIA":
            publisher.publish_control_command(command="set_fan", target="fan", state="on", source="automation")
            db.events.insert_one({
                "event_type": "gas_warning",
                "message": f"ADVERTENCIA: Nivel de gas elevado ({gas_val:.1f} ppm). Ventilación activada.",
                "severity": "warning",
                "area": "control",
                "source": "backend_rules",
                "created_at": now,
            })
    else:
        updates["gas_state"] = "GAS_NORMAL"
        if prev_gas == "GAS_EMERGENCIA":
            publisher = MQTTPublisher()
            publisher.publish_control_command(command="set_buzzer", target="buzzer", state="off", source="automation")
        if prev_gas == "GAS_EMERGENCIA" or prev_gas == "GAS_ADVERTENCIA":
            publisher = MQTTPublisher()
            if temp <= 30.0:
                publisher.publish_control_command(command="set_fan", target="fan", state="off", source="automation")
            db.events.insert_one({
                "event_type": "gas_cleared",
                "message": "Gas ha vuelto a niveles normales.",
                "severity": "info",
                "area": "control",
                "source": "backend_rules",
                "created_at": now,
            })

    if updates.get("gas_state") != "GAS_EMERGENCIA":
        prev_temp = latest.get("temperature", 0.0) if latest else 0.0
        logger.info("DEBUG temp=%.1f prev_temp=%.1f gas_state=%s mode=%s",
                     temp, prev_temp, updates.get("gas_state"), latest.get("mode") if latest else "none")
        if temp > 30.0:
            updates["overall_state"] = "ADVERTENCIA"
            updates["ventilation_state"] = "VENTILACION_ON"
            updates["fan_active"] = True
            if prev_temp <= 30.0:
                publisher = MQTTPublisher()
                publisher.publish_control_command(command="set_fan", target="fan", state="on", source="automation")
                db.events.insert_one({
                    "event_type": "temp_warning",
                    "message": f"ADVERTENCIA: Temperatura alta detectada ({temp:.1f} °C). Activando ventilación.",
                    "severity": "warning",
                    "area": "control",
                    "source": "backend_rules",
                    "created_at": now,
                })
                logger.warning("Temperatura alta: %.1f °C, fan ON enviado", temp)
        else:
            if updates.get("gas_state") != "GAS_ADVERTENCIA":
                updates["ventilation_state"] = "VENTILACION_OFF"
                updates["fan_active"] = False
                if prev_temp > 30.0:
                    publisher = MQTTPublisher()
                    publisher.publish_control_command(command="set_fan", target="fan", state="off", source="automation")
            else:
                updates["ventilation_state"] = "VENTILACION_ON"
                updates["fan_active"] = True

    # Iluminación automática según LDR (solo en modo auto)
    # Rango típico: ~96% (luz directa) ~60% (oscuridad total)
    LIGHT_LOW = 65.0    # por debajo = encender luces
    LIGHT_HIGH = 65.0   # por encima = apagar luces
    if updates.get("gas_state") != "GAS_EMERGENCIA":
        prev_lights = latest.get("lights_active", False) if latest else False
        mode = latest.get("mode", "auto") if latest else "auto"
        if mode == "auto":
            if light_val < LIGHT_LOW and not prev_lights:
                updates["lights_active"] = True
                publisher = MQTTPublisher()
                publisher.publish_control_command(
                    command="set_lights", target="lights", state="on", source="automation",
                )
                db.events.insert_one({
                    "event_type": "light_warning",
                    "message": f"Poca luz detectada ({light_val:.1f}%). Encendiendo iluminación artificial.",
                    "severity": "info",
                    "area": "control",
                    "source": "backend_rules",
                    "created_at": now,
                })
                logger.info("Poca luz (%.1f%%), luces encendidas", light_val)
            elif light_val > LIGHT_HIGH and prev_lights:
                updates["lights_active"] = False
                publisher = MQTTPublisher()
                publisher.publish_control_command(
                    command="set_lights", target="lights", state="off", source="automation",
                )
                db.events.insert_one({
                    "event_type": "light_restored",
                    "message": f"Luz suficiente ({light_val:.1f}%). Apagando iluminación artificial.",
                    "severity": "info",
                    "area": "control",
                    "source": "backend_rules",
                    "created_at": now,
                })
                logger.info("Luz suficiente (%.1f%%), luces apagadas", light_val)

    if updates.get("gas_state") != "GAS_EMERGENCIA":
        pump_blocked_until = latest.get("_pump_blocked_until") if latest else None
        if pump_blocked_until:
            if isinstance(pump_blocked_until, str):
                pump_blocked_until = datetime.fromisoformat(pump_blocked_until.replace("Z", "+00:00"))
            if now < pump_blocked_until:
                pass
            else:
                pump_blocked_until = None

        soil1_saturated = soil1 > 80.0
        soil2_saturated = soil2 > 80.0

        if soil1_saturated and soil2_saturated:
            updates["irrigation_state"] = "BLOQUEADO_POR_SATURACION"
            updates["pump_active"] = False
            if prev_pump:
                db.events.insert_one({
                    "event_type": "soil_warning",
                    "message": "BLOQUEO: Ambas áreas saturadas. Riego desactivado.",
                    "severity": "warning",
                    "area": "control",
                    "source": "backend_rules",
                    "created_at": now,
                })
        elif soil1_saturated:
            if prev_irrigation == "RIEGO_AREA_1" or (prev_pump and prev_irrigation != "RIEGO_AREA_2"):
                updates["irrigation_state"] = "BLOQUEADO_POR_SATURACION"
                updates["pump_active"] = False
                if prev_pump:
                    db.events.insert_one({
                        "event_type": "soil_warning",
                        "message": f"BLOQUEO: Suelo Área 1 saturado ({soil1:.1f}%). Riego desactivado.",
                        "severity": "warning",
                        "area": "area_1",
                        "source": "backend_rules",
                        "created_at": now,
                    })
        elif soil2_saturated:
            if prev_irrigation == "RIEGO_AREA_2" or (prev_pump and prev_irrigation != "RIEGO_AREA_1"):
                updates["irrigation_state"] = "BLOQUEADO_POR_SATURACION"
                updates["pump_active"] = False
                if prev_pump:
                    db.events.insert_one({
                        "event_type": "soil_warning",
                        "message": f"BLOQUEO: Suelo Área 2 saturado ({soil2:.1f}%). Riego desactivado.",
                        "severity": "warning",
                        "area": "area_2",
                        "source": "backend_rules",
                        "created_at": now,
                    })

        if updates.get("irrigation_state") != "BLOQUEADO_POR_SATURACION":
            if soil1 < 30.0:
                updates["irrigation_state"] = "RIEGO_AREA_1"
                updates["pump_active"] = True
                if not prev_pump and pump_blocked_until is None:
                    updates["pump_started_at"] = now.isoformat()
                    db.events.insert_one({
                        "event_type": "soil_warning",
                        "message": f"Suelo Área 1 seco ({soil1:.1f}%). Activando riego Área 1.",
                        "severity": "warning",
                        "area": "area_1",
                        "source": "backend_rules",
                        "created_at": now,
                    })
            elif soil2 < 30.0:
                updates["irrigation_state"] = "RIEGO_AREA_2"
                updates["pump_active"] = True
                if not prev_pump and pump_blocked_until is None:
                    updates["pump_started_at"] = now.isoformat()
                    db.events.insert_one({
                        "event_type": "soil_warning",
                        "message": f"Suelo Área 2 seco ({soil2:.1f}%). Activando riego Área 2.",
                        "severity": "warning",
                        "area": "area_2",
                        "source": "backend_rules",
                        "created_at": now,
                    })
            else:
                updates["irrigation_state"] = "RIEGO_OFF"
                if prev_pump:
                    updates["pump_active"] = False
                    updates["pump_started_at"] = None
                    updates["pump_last_stopped_at"] = now.isoformat()
                    db.events.insert_one({
                        "event_type": "irrigation_stopped",
                        "message": "Suelo en nivel normal. Riego desactivado.",
                        "severity": "info",
                        "area": "control",
                        "source": "backend_rules",
                        "created_at": now,
                    })

        if updates.get("irrigation_state") == "BLOQUEADO_POR_SATURACION":
            updates["pump_active"] = False
            updates["pump_started_at"] = None

    pump_is_active = updates.get("pump_active", prev_pump)
    if pump_is_active and updates.get("overall_state") not in ("EMERGENCIA",):
        updates["overall_state"] = "RIEGO_ACTIVO"

    if updates.get("overall_state") not in ("EMERGENCIA", "ADVERTENCIA", "RIEGO_ACTIVO", "MODO_MANUAL"):
        updates["overall_state"] = "NORMAL"
        if prev_overall in ("ADVERTENCIA", "EMERGENCIA", "RIEGO_ACTIVO"):
            if not (prev_pump and pump_is_active):
                updates["pump_active"] = False
                updates["fan_active"] = updates.get("fan_active") if latest and latest.get("mode") == "manual" else False
                updates["buzzer_active"] = False
                db.events.insert_one({
                    "event_type": "status_restored",
                    "message": "Todos los sensores han retornado a rangos normales.",
                    "severity": "info",
                    "area": "control",
                    "source": "backend_rules",
                    "created_at": now,
                })
