import logging
from datetime import datetime, timezone

from ..db import get_database
from ..mqtt.publisher import MQTTPublisher
from .sensor_service import update_system_status

logger = logging.getLogger(__name__)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def execute_control(actuator: str, state: str, area: str | None = None) -> dict:
    db = get_database()
    publisher = MQTTPublisher()

    # En modo auto solo se permite cambiar el modo
    if actuator != "mode":
        latest = db.system_status.find_one(sort=[("updated_at", -1)])
        mode = (latest or {}).get("mode", "auto")
        if mode == "auto":
            logger.info("Control ignorado (modo auto): %s -> %s (area=%s)", actuator, state, area)
            return {
                "command_id": None,
                "log_id": None,
                "mqtt": None,
                "ignored": True,
                "reason": "modo_auto_no_permite_control_manual",
            }

    command_document = {
        "command": f"set_{actuator}",
        "target": actuator,
        "source": "web",
        "payload": {"state": state, "area": area},
        "created_at": _now(),
    }
    command_result = db.commands.insert_one(command_document)

    log_document = {
        "actuator": actuator,
        "action": state,
        "source": "web",
        "area": area,
        "payload": {"state": state},
        "created_at": _now(),
    }
    log_result = db.actuator_logs.insert_one(log_document)

    updates = _compute_status_updates(actuator, state, area, db)
    if updates:
        update_system_status(updates)

    mqtt_result = None
    if actuator == "mode":
        mqtt_result = publisher.publish_control_command(
            command=f"set_{actuator}",
            target=actuator,
            state=state,
            source="web",
        )
    else:
        mqtt_result = publisher.publish_actuator_event(
            actuator=actuator,
            action=state,
            area=area,
            source="web",
        )

    logger.info("Control ejecutado: %s -> %s (area=%s)", actuator, state, area)

    return {
        "command_id": str(command_result.inserted_id),
        "log_id": str(log_result.inserted_id),
        "mqtt": {
            "actuator": (
                {
                    "published": mqtt_result.success,
                    "topic": mqtt_result.topic,
                    "message": mqtt_result.message,
                }
                if mqtt_result
                else None
            ),
        },
    }


def _compute_status_updates(actuator: str, state: str, area: str | None, db) -> dict:
    updates = {}
    latest = db.system_status.find_one(sort=[("updated_at", -1)])

    if actuator == "mode":
        updates["mode"] = state
        if state == "manual":
            updates["overall_state"] = "MODO_MANUAL"
            updates["irrigation_state"] = "RIEGO_MANUAL"
            updates["ventilation_state"] = "VENTILACION_MANUAL"
        elif state == "auto":
            updates["overall_state"] = "NORMAL"
            updates["irrigation_state"] = "RIEGO_OFF"
            updates["ventilation_state"] = "VENTILACION_OFF"

    elif actuator in ("pump", "irrigation"):
        is_on = state == "on"
        updates["pump_active"] = is_on
        if is_on:
            if area == "area_1":
                updates["irrigation_state"] = "RIEGO_AREA_1"
            elif area == "area_2":
                updates["irrigation_state"] = "RIEGO_AREA_2"
            else:
                updates["irrigation_state"] = "RIEGO_MANUAL"
            updates["pump_started_at"] = _now().isoformat()
            updates["overall_state"] = "RIEGO_ACTIVO"
        else:
            updates["irrigation_state"] = "RIEGO_OFF"
            updates["pump_started_at"] = None
            updates["pump_last_stopped_at"] = _now().isoformat()
            mode = latest.get("mode", "auto") if latest else "auto"
            updates["overall_state"] = "MODO_MANUAL" if mode == "manual" else "NORMAL"

    elif actuator == "fan":
        is_on = state == "on"
        updates["fan_active"] = is_on
        mode = latest.get("mode", "auto") if latest else "auto"
        if mode == "manual":
            updates["ventilation_state"] = "VENTILACION_ON" if is_on else "VENTILACION_OFF"

    elif actuator == "lights":
        is_on = state == "on"
        updates["lights_active"] = is_on

    elif actuator in ("buzzer", "alarm"):
        updates["buzzer_active"] = state in ("on", "active")

    return updates
