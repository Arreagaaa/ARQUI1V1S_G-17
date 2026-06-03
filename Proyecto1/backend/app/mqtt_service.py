"""
Servicio MQTT legacy — Wrapper sobre la nueva capa MQTT desacoplada.

Mantiene compatibilidad con el código existente mientras delega
a la nueva infraestructura MQTT (connection_manager, publisher, etc.).
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass

from .config import get_settings
from .mqtt.publisher import MQTTPublisher, PublishResult

logger = logging.getLogger(__name__)


@dataclass
class MQTTResult:
    """Resultado de una operación MQTT (legacy API)."""

    connected: bool
    published: bool
    message: str


def publish_control_event(topic_suffix: str, payload: dict) -> MQTTResult:
    """
    Publica un evento de control vía MQTT (API legacy).

    Delegado a MQTTPublisher de la nueva capa desacoplada.
    """
    settings = get_settings()
    topic = f"{settings.mqtt_base_topic}/{topic_suffix}"

    if not settings.enable_mqtt:
        return MQTTResult(False, False, f"MQTT deshabilitado (dry run). Topic: {topic}")

    try:
        publisher = MQTTPublisher()
        result = publisher._publish(topic, payload)
        return MQTTResult(result.success, result.success, result.message)
    except Exception as exc:
        logger.error("Error publicando evento MQTT en '%s': %s", topic, exc)
        return MQTTResult(False, False, f"{topic}: {exc}")