"""
MQTTMessageHandlers — Handlers que procesan los mensajes MQTT entrantes
y los persisten en MongoDB según el contrato del proyecto.

Cuando el backend se conecta al broker:
- Recibe lecturas de sensores → las guarda en sensor_readings y actualiza estado
- Recibe comandos de control → los guarda en commands y ejecuta
- Recibe eventos de actuadores → los guarda en actuator_logs
- Recibe estado global → actualiza system_status
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from ..db import get_database
from ..services.control_service import execute_control
from ..services.sensor_service import process_reading

logger = logging.getLogger(__name__)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def handle_sensor_message(topic: str, payload: dict) -> None:
    """
    Handler para mensajes de sensores.

    Topic esperado: grupo17/invernadero/sensores/<tipo>
    Persiste en colección sensor_readings y procesa reglas de automatización.
    """
    try:
        db = get_database()
        sensor_type = payload.get("sensor_type")
        value = payload.get("value")
        source = payload.get("source", "mqtt")
        if sensor_type is None or value is None:
            logger.warning("MQTT sensor message sin sensor_type/value: %s", payload)
            return

        # Evitar re-entrada: cuando el dashboard inserta una lectura vía API
        # (POST /api/readings) el backend la publica con source "web" y el
        # subscriber la recibe. NO filtramos "raspi-01" porque ese source
        # es el del Raspberry Pi real, que sí debe procesarse.
        if source in ("web", "api", "dashboard", "backend", "system"):
            logger.debug("MQTT sensor ignorado (source=self): %s = %s", sensor_type, value)
            return

        document = {
            "sensor_type": sensor_type,
            "value": float(value),
            "unit": payload.get("unit", ""),
            "area": payload.get("area", "control"),
            "status": payload.get("status", "normal"),
            "source": source,
            "recorded_at": _parse_timestamp(payload.get("timestamp")) or _now(),
        }
        db.sensor_readings.insert_one(document)
        process_reading(document)
        logger.debug("MQTT sensor persistido: %s = %.1f", sensor_type, value)
    except Exception as exc:
        logger.error("Error procesando mensaje MQTT de sensor en '%s': %s", topic, exc)


def handle_actuator_message(topic: str, payload: dict) -> None:
    """
    Handler para mensajes de actuadores.

    Topic esperado: grupo17/invernadero/actuadores/<nombre>
    Persiste en colección actuator_logs.
    """
    try:
        db = get_database()
        actuator = payload.get("actuator")
        action = payload.get("action")
        source = payload.get("source", "mqtt")
        if not actuator or not action:
            logger.warning("MQTT actuator message sin actuator/action: %s", payload)
            return

        # Evitar re-entrada: el backend publica eventos de actuador desde
        # control_service. NO filtramos "raspi-01" porque ese source es
        # del Raspberry Pi real, que sí debe procesarse.
        if source in ("web", "api", "dashboard", "backend", "system"):
            logger.debug("MQTT actuator ignorado (source=self): %s -> %s", actuator, action)
            return

        document = {
            "actuator": actuator,
            "action": action,
            "source": source,
            "area": payload.get("area"),
            "payload": payload.get("payload", {}),
            "created_at": _parse_timestamp(payload.get("timestamp")) or _now(),
        }
        db.actuator_logs.insert_one(document)
        logger.debug("MQTT actuator persistido: %s -> %s", actuator, action)
    except Exception as exc:
        logger.error("Error procesando mensaje MQTT de actuador en '%s': %s", topic, exc)


def handle_control_message(topic: str, payload: dict) -> None:
    """
    Handler para mensajes de control remoto.

    Topic esperado: grupo17/invernadero/control/remoto  o  .../control/manual
    Persiste el comando en commands y ejecuta el control (que actualiza
    el estado global y publica de vuelta al broker).
    """
    try:
        db = get_database()
        command = payload.get("command", "unknown")
        target = payload.get("target", "system")
        source = payload.get("source", "mqtt")
        sub_payload = payload.get("payload", {}) or {}

        # Evitar re-entrada: el backend publica sus propios comandos a
        # control/remoto con source "web" o "api". El subscriber los
        # recibe y los procesaría, generando un loop.
        if source in ("web", "api", "backend", "system"):
            logger.debug("MQTT command ignorado (source=self): %s -> %s", command, target)
            return

        document = {
            "command": command,
            "target": target,
            "source": source,
            "payload": sub_payload,
            "created_at": _parse_timestamp(payload.get("timestamp")) or _now(),
        }
        db.commands.insert_one(document)
        logger.info("MQTT command persistido: %s -> %s", command, target)

        # Si es un set_<actuador> ejecutable, despachar al servicio de control
        if command.startswith("set_") and target in ("pump", "fan", "lights", "buzzer", "mode", "irrigation"):
            state = sub_payload.get("state", "on")
            area = sub_payload.get("area")
            try:
                execute_control(target, state, area)
            except Exception as exc:
                logger.warning("No se pudo ejecutar control desde MQTT: %s", exc)
    except Exception as exc:
        logger.error("Error procesando mensaje MQTT de control en '%s': %s", topic, exc)


def handle_global_state_message(topic: str, payload: dict) -> None:
    """
    Handler para mensajes de estado global reportados por la Raspberry Pi.

    Topic esperado: grupo17/invernadero/estado/global
    Persiste en colección system_status (snapshot histórico).
    """
    try:
        db = get_database()
        source = payload.get("source", "mqtt")

        # Evitar re-entrada: el backend publica su propio global state
        # desde update_system_status. El subscriber lo recibiría y
        # duplicaría el snapshot.
        if source in ("web", "api", "backend", "system"):
            logger.debug("MQTT global state ignorado (source=self)")
            return

        document = dict(payload)
        document["updated_at"] = _parse_timestamp(payload.get("timestamp")) or _now()
        document["source"] = source
        db.system_status.insert_one(document)
        logger.debug("MQTT global state persistido: %s", payload.get("overall_state"))
    except Exception as exc:
        logger.error("Error procesando mensaje MQTT de estado global en '%s': %s", topic, exc)


def _parse_timestamp(value):
    """Parsea un timestamp ISO 8601 a datetime; devuelve None si es inválido."""
    if not value:
        return None
    try:
        if isinstance(value, datetime):
            return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None
