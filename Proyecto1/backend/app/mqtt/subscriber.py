"""
MQTTSubscriber — Suscripción desacoplada a topics MQTT.

Permite registrar handlers para categorías de topics (sensores, actuadores,
control, estado global) de forma desacoplada del ConnectionManager.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Callable

from .connection_manager import MQTTConnectionManager
from .topic_registry import MQTTTopicRegistry
from .payload_validator import MQTTPayloadValidator

logger = logging.getLogger(__name__)

MessageHandler = Callable[[str, dict[str, Any]], None]


class MQTTSubscriber:
    """
    Suscriptor MQTT con handlers registrados por categoría de topic.

    Uso:
        subscriber = MQTTSubscriber()
        subscriber.on_sensor_data(my_sensor_handler)
        subscriber.on_control_command(my_control_handler)
        subscriber.start()
    """

    def __init__(self) -> None:
        self.manager = MQTTConnectionManager()
        self.topics = MQTTTopicRegistry()
        self.validator = MQTTPayloadValidator()
        self._handlers: dict[str, list[MessageHandler]] = {
            "sensors": [],
            "actuators": [],
            "control": [],
            "global_state": [],
        }

    def on_sensor_data(self, handler: MessageHandler) -> None:
        """Registra un handler para datos de sensores."""
        self._handlers["sensors"].append(handler)

    def on_actuator_event(self, handler: MessageHandler) -> None:
        """Registra un handler para eventos de actuadores."""
        self._handlers["actuators"].append(handler)

    def on_control_command(self, handler: MessageHandler) -> None:
        """Registra un handler para comandos de control."""
        self._handlers["control"].append(handler)

    def on_global_state(self, handler: MessageHandler) -> None:
        """Registra un handler para estado global."""
        self._handlers["global_state"].append(handler)

    def _dispatch(self, category: str, topic: str, payload: bytes) -> None:
        """Despacha un mensaje a los handlers registrados para una categoría."""
        try:
            data = json.loads(payload.decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            logger.error("Error deserializando mensaje MQTT de '%s': %s", topic, exc)
            return

        for handler in self._handlers.get(category, []):
            try:
                handler(topic, data)
            except Exception as exc:
                logger.error("Error en handler '%s' para topic '%s': %s",
                             handler.__name__, topic, exc)

    def start(self) -> None:
        """
        Inicia la suscripción a todos los topics configurados.
        Registra callbacks en el ConnectionManager para cada categoría.
        """
        base = self.topics.base

        # Suscribir a sensores: invernadero/sensores/#
        self.manager.subscribe(
            f"{base}/sensores/#",
            lambda topic, payload: self._dispatch("sensors", topic, payload),
        )

        # Suscribir a actuadores: invernadero/actuadores/#
        self.manager.subscribe(
            f"{base}/actuadores/#",
            lambda topic, payload: self._dispatch("actuators", topic, payload),
        )

        # Suscribir a control: invernadero/control/#
        self.manager.subscribe(
            f"{base}/control/#",
            lambda topic, payload: self._dispatch("control", topic, payload),
        )

        # Suscribir a estado global: invernadero/estado/global
        self.manager.subscribe(
            self.topics.global_state,
            lambda topic, payload: self._dispatch("global_state", topic, payload),
        )

        logger.info("MQTTSubscriber iniciado — suscrito a %s/#", base)
