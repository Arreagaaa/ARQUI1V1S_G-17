"""
MQTTPublisher — Publicación desacoplada de mensajes MQTT.

Utiliza el MQTTConnectionManager y el MQTTTopicRegistry para publicar
mensajes de forma estandarizada según el contrato oficial.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from datetime import datetime, timezone

from .connection_manager import MQTTConnectionManager
from .topic_registry import MQTTTopicRegistry

logger = logging.getLogger(__name__)


@dataclass
class PublishResult:
    """Resultado de una operación de publicación MQTT."""

    success: bool
    topic: str
    message: str


class MQTTPublisher:
    """Publica mensajes MQTT según el contrato del proyecto."""

    def __init__(self) -> None:
        self.manager = MQTTConnectionManager()
        self.topics = MQTTTopicRegistry()

    def _publish(self, topic: str, payload: dict) -> PublishResult:
        """Publica un payload serializado como JSON en el topic indicado."""
        try:
            data = json.dumps(payload, ensure_ascii=False, default=str)
            if self.manager.is_enabled:
                success = self.manager.publish(topic, data)
                return PublishResult(success, topic, "Publicado" if success else "Error de publicación")
            else:
                logger.debug("MQTT dry-run: %s -> %s", topic, data[:100])
                return PublishResult(False, topic, f"MQTT deshabilitado (dry-run). Topic: {topic}")
        except Exception as exc:
            logger.error("Error publicando MQTT en '%s': %s", topic, exc)
            return PublishResult(False, topic, f"Error: {exc}")

    def publish_sensor_reading(self, sensor_type: str, value: float, unit: str,
                               area: str, status: str = "normal",
                               source: str = "raspi-01") -> PublishResult:
        """Publica una lectura de sensor."""
        topic = self.topics.get_sensor_topic(sensor_type)
        payload = {
            "sensor_type": sensor_type,
            "value": value,
            "unit": unit,
            "area": area,
            "status": status,
            "source": source,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        return self._publish(topic, payload)

    def publish_actuator_event(self, actuator: str, action: str,
                               area: str | None = None,
                               source: str = "raspi-01",
                               extra_payload: dict | None = None) -> PublishResult:
        """Publica un evento de cambio de actuador."""
        topic = self.topics.get_actuator_topic(actuator, area)
        payload = {
            "actuator": actuator,
            "action": action,
            "area": area,
            "source": source,
            "payload": extra_payload or {},
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        return self._publish(topic, payload)

    def publish_control_command(self, command: str, target: str,
                                state: str, area: str | None = None,
                                source: str = "web",
                                extra_payload: dict | None = None) -> PublishResult:
        """Publica un comando de control remoto."""
        topic = self.topics.control_remote
        pl = {"state": state, "area": area}
        if extra_payload:
            pl.update(extra_payload)
        payload = {
            "command": command,
            "target": target,
            "source": source,
            "payload": pl,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        return self._publish(topic, payload)

    def publish_global_state(self, state: dict) -> PublishResult:
        """Publica el estado global del sistema."""
        topic = self.topics.global_state
        if "timestamp" not in state:
            state["timestamp"] = datetime.now(timezone.utc).isoformat()
        return self._publish(topic, state)
