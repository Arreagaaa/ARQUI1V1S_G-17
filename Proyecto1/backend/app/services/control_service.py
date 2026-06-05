"""
ControlService — Lógica de negocio para control de actuadores.

Centraliza la lógica de control manual que actualiza el estado global,
registra comandos y logs de actuadores, y publica vía MQTT.
"""

import logging
from datetime import datetime, timezone

from ..db import get_database
from ..mqtt.publisher import MQTTPublisher
from .sensor_service import update_system_status

logger = logging.getLogger(__name__)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def execute_control(actuator: str, state: str, area: str | None = None) -> dict:
    """
    Ejecuta un comando de control sobre un actuador.

    1. Registra el comando en la colección `commands`
    2. Registra un log en la colección `actuator_logs`
    3. Actualiza el estado global del sistema
    4. Publica UN SOLO mensaje vía MQTT al topic de actuador correspondiente
       (el dashboard/raspberry suscrito a `invernadero/control/#` se entera
        del cambio por la actualización de estado global, evitando duplicados)

    Args:
        actuator: Identificador del actuador (pump, fan, lights, buzzer, mode)
        state: Estado deseado (on, off, auto, manual, mute)
        area: Área opcional (area_1, area_2)

    Returns:
        Diccionario con IDs de los documentos creados y resultado MQTT
    """
    db = get_database()
    publisher = MQTTPublisher()

    # 1. Registrar comando
    command_document = {
        "command": f"set_{actuator}",
        "target": actuator,
        "source": "web",
        "payload": {"state": state, "area": area},
        "created_at": _now(),
    }
    command_result = db.commands.insert_one(command_document)

    # 2. Registrar log de actuador
    log_document = {
        "actuator": actuator,
        "action": state,
        "source": "web",
        "area": area,
        "payload": {"state": state},
        "created_at": _now(),
    }
    log_result = db.actuator_logs.insert_one(log_document)

    # 3. Actualizar estado global según tipo de actuador
    updates = _compute_status_updates(actuator, state, db)
    if updates:
        update_system_status(updates)

    # 4. Publicar UN SOLO mensaje MQTT al topic del actuador (no duplicar)
    mqtt_result = None
    if actuator != "mode":
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


def _compute_status_updates(actuator: str, state: str, db) -> dict:
    """Calcula las actualizaciones de estado global según el actuador controlado."""

    updates = {}

    if actuator == "mode":
        updates["mode"] = state
        if state == "manual":
            updates["overall_state"] = "MODO_MANUAL"
        elif state == "auto":
            updates["overall_state"] = "NORMAL"

    elif actuator in ("pump", "irrigation"):
        updates["pump_active"] = (state == "on")
        if state == "on":
            updates["overall_state"] = "RIEGO_ACTIVO"
        else:
            latest = db.system_status.find_one(sort=[("updated_at", -1)])
            mode = latest.get("mode", "auto") if latest else "auto"
            updates["overall_state"] = "MODO_MANUAL" if mode == "manual" else "NORMAL"

    elif actuator == "fan":
        updates["fan_active"] = (state == "on")

    elif actuator == "lights":
        updates["lights_active"] = (state == "on")

    elif actuator in ("buzzer", "alarm"):
        # Corregido: la lógica anterior tenía un bug donde `state != "mute"`
        # siempre era True excepto para "mute". Ahora es explícito.
        updates["buzzer_active"] = state in ("on", "active")

    return updates
