"""
MQTTPayloadValidator — Validación de payloads MQTT contra schemas Pydantic.

Valida los payloads recibidos y enviados por MQTT para garantizar conformidad
con el contrato oficial del proyecto.
"""

import json
import logging
from typing import Any

from pydantic import ValidationError

from ..schemas import (
    SensorMQTTPayload,
    ActuatorMQTTPayload,
    CommandMQTTPayload,
    GlobalStateMQTTPayload,
)

logger = logging.getLogger(__name__)


class MQTTPayloadValidator:
    """Valida y deserializa payloads MQTT según el contrato oficial."""

    # Mapeo de prefijos de topic a modelos Pydantic
    TOPIC_MODEL_MAP = {
        "sensores/": SensorMQTTPayload,
        "actuadores/": ActuatorMQTTPayload,
        "control/": CommandMQTTPayload,
        "estado/global": GlobalStateMQTTPayload,
    }

    @staticmethod
    def parse_payload(raw: bytes | str) -> dict[str, Any]:
        """Parsea un payload JSON desde bytes o string."""
        if isinstance(raw, bytes):
            raw = raw.decode("utf-8")
        try:
            return json.loads(raw)
        except json.JSONDecodeError as exc:
            logger.error("Payload MQTT no es JSON válido: %s", exc)
            raise ValueError(f"Invalid JSON payload: {exc}") from exc

    def validate_sensor(self, payload: dict[str, Any]) -> SensorMQTTPayload:
        """Valida un payload de sensor."""
        try:
            return SensorMQTTPayload(**payload)
        except ValidationError as exc:
            logger.warning("Payload de sensor inválido: %s", exc)
            raise

    def validate_actuator(self, payload: dict[str, Any]) -> ActuatorMQTTPayload:
        """Valida un payload de actuador."""
        try:
            return ActuatorMQTTPayload(**payload)
        except ValidationError as exc:
            logger.warning("Payload de actuador inválido: %s", exc)
            raise

    def validate_command(self, payload: dict[str, Any]) -> CommandMQTTPayload:
        """Valida un payload de comando."""
        try:
            return CommandMQTTPayload(**payload)
        except ValidationError as exc:
            logger.warning("Payload de comando inválido: %s", exc)
            raise

    def validate_global_state(self, payload: dict[str, Any]) -> GlobalStateMQTTPayload:
        """Valida un payload de estado global."""
        try:
            return GlobalStateMQTTPayload(**payload)
        except ValidationError as exc:
            logger.warning("Payload de estado global inválido: %s", exc)
            raise

    def validate_by_topic(self, topic: str, payload: dict[str, Any]) -> Any:
        """
        Valida un payload basándose en el topic MQTT.

        Args:
            topic: Topic MQTT completo (e.g. invernadero/sensores/temperatura)
            payload: Diccionario del payload recibido

        Returns:
            Instancia del modelo Pydantic validada
        """
        for prefix, model in self.TOPIC_MODEL_MAP.items():
            if prefix in topic:
                try:
                    return model(**payload)
                except ValidationError as exc:
                    logger.warning("Payload inválido para topic '%s': %s", topic, exc)
                    raise

        logger.warning("No se encontró modelo de validación para topic: %s", topic)
        return payload
