from __future__ import annotations

import json
from dataclasses import dataclass

import paho.mqtt.client as mqtt

from .config import get_settings


@dataclass
class MQTTResult:
    connected: bool
    published: bool
    message: str


def _client() -> mqtt.Client:
    settings = get_settings()
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    if settings.mqtt_username:
        client.username_pw_set(settings.mqtt_username, settings.mqtt_password)
    return client


def publish_control_event(topic_suffix: str, payload: dict) -> MQTTResult:
    settings = get_settings()
    topic = f"{settings.mqtt_base_topic}/{topic_suffix}"
    client = _client()

    try:
        client.connect(settings.mqtt_host, settings.mqtt_port, keepalive=30)
        client.publish(topic, json.dumps(payload, ensure_ascii=False), qos=1)
        client.disconnect()
        return MQTTResult(True, True, topic)
    except Exception as exc:
        return MQTTResult(False, False, f"{topic}: {exc}")