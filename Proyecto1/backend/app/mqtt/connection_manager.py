"""
MQTTConnectionManager — Gestión centralizada de conexión al broker MQTT.

Broker de desarrollo: broker.emqx.io
Puertos: 1883 (sin SSL), 8883 (con SSL)

NO usar Docker. NO usar Mosquitto local. NO crear brokers propios.
Cuando se integre MQTTX Web, se conectará a broker.emqx.io directamente.
"""

from __future__ import annotations

import logging
from typing import Any, Callable

import paho.mqtt.client as mqtt

from ..config import get_settings

logger = logging.getLogger(__name__)


class MQTTConnectionManager:
    """
    Gestor de conexión MQTT tipo Singleton.

    Uso:
        manager = MQTTConnectionManager()
        manager.connect()
        manager.publish("grupo17/invernadero/sensores/temperatura", payload)
        manager.subscribe("grupo17/invernadero/control/#", callback)
        manager.disconnect()
    """

    _instance: MQTTConnectionManager | None = None

    def __new__(cls) -> MQTTConnectionManager:
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self) -> None:
        if self._initialized:
            return
        self._initialized = True

        settings = get_settings()
        self._enabled = settings.enable_mqtt
        self._host = settings.mqtt_host
        self._port = settings.mqtt_port
        self._username = settings.mqtt_username
        self._password = settings.mqtt_password
        self._connected = False
        self._callbacks: dict[str, list[Callable]] = {}

        self._client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

        if self._username:
            self._client.username_pw_set(self._username, self._password)

        self._client.on_connect = self._on_connect
        self._client.on_disconnect = self._on_disconnect
        self._client.on_message = self._on_message

    @property
    def is_enabled(self) -> bool:
        return self._enabled

    @property
    def is_connected(self) -> bool:
        return self._connected

    def _on_connect(self, client: mqtt.Client, userdata: Any, flags: Any,
                    reason_code: Any, properties: Any) -> None:
        self._connected = True
        logger.info("Conectado al broker MQTT: %s:%s", self._host, self._port)

        # Re-suscribir a todos los topics registrados
        for topic in self._callbacks:
            client.subscribe(topic, qos=1)
            logger.info("Re-suscrito a topic: %s", topic)

    def _on_disconnect(self, client: mqtt.Client, userdata: Any, flags: Any,
                       reason_code: Any, properties: Any) -> None:
        self._connected = False
        logger.warning("Desconectado del broker MQTT (reason: %s)", reason_code)

    def _on_message(self, client: mqtt.Client, userdata: Any,
                    message: mqtt.MQTTMessage) -> None:
        topic = message.topic
        logger.debug("Mensaje recibido en topic: %s", topic)

        for registered_topic, callbacks in self._callbacks.items():
            if mqtt.topic_matches_sub(registered_topic, topic):
                for callback in callbacks:
                    try:
                        callback(topic, message.payload)
                    except Exception as exc:
                        logger.error("Error en callback MQTT para '%s': %s", topic, exc)

    def connect(self) -> bool:
        """
        Conecta al broker MQTT.

        Returns:
            True si la conexión fue exitosa, False si MQTT está deshabilitado.
        """
        if not self._enabled:
            logger.info("MQTT está deshabilitado (ENABLE_MQTT=false). Modo dry-run.")
            return False

        try:
            self._client.connect(self._host, self._port, keepalive=60)
            self._client.loop_start()
            logger.info("Iniciando conexión MQTT a %s:%s", self._host, self._port)
            return True
        except Exception as exc:
            logger.error("Error conectando al broker MQTT: %s", exc)
            return False

    def disconnect(self) -> None:
        """Desconecta del broker MQTT."""
        try:
            self._client.loop_stop()
            self._client.disconnect()
            logger.info("Desconectado del broker MQTT.")
        except Exception as exc:
            logger.error("Error desconectando MQTT: %s", exc)

    def subscribe(self, topic: str, callback: Callable[[str, bytes], None]) -> None:
        """
        Suscribe a un topic MQTT con un callback.

        Args:
            topic: Topic MQTT (soporta wildcards # y +)
            callback: Función que recibe (topic: str, payload: bytes)
        """
        if topic not in self._callbacks:
            self._callbacks[topic] = []
        self._callbacks[topic].append(callback)

        if self._connected:
            self._client.subscribe(topic, qos=1)
            logger.info("Suscrito a topic: %s", topic)

    def publish(self, topic: str, payload: str | bytes, qos: int = 1) -> bool:
        """
        Publica un mensaje en un topic MQTT.

        Args:
            topic: Topic MQTT destino
            payload: Payload JSON serializado
            qos: Nivel de calidad del servicio (0, 1, 2)

        Returns:
            True si se publicó correctamente
        """
        if not self._enabled:
            logger.debug("MQTT dry-run: publish to '%s'", topic)
            return False

        if not self._connected:
            logger.warning("No se puede publicar: no conectado al broker MQTT.")
            return False

        try:
            result = self._client.publish(topic, payload, qos=qos)
            result.wait_for_publish(timeout=5)
            logger.debug("Publicado en '%s'", topic)
            return True
        except Exception as exc:
            logger.error("Error publicando en '%s': %s", topic, exc)
            return False

    @classmethod
    def reset(cls) -> None:
        """Resetea el singleton (útil para testing)."""
        if cls._instance is not None:
            cls._instance.disconnect()
            cls._instance = None
