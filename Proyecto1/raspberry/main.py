from __future__ import annotations

import json
import os
import time
from dataclasses import dataclass
from typing import Any

import paho.mqtt.client as mqtt
import requests
from dotenv import load_dotenv

try:
    import RPi.GPIO as GPIO  # type: ignore
except Exception:  # pragma: no cover - Raspberry only dependency
    GPIO = None


load_dotenv()


@dataclass(frozen=True)
class Settings:
    backend_url: str
    mqtt_host: str
    mqtt_port: int
    mqtt_username: str
    mqtt_password: str
    mqtt_base_topic: str
    device_id: str
    enable_gpio: bool
    poll_interval_seconds: int
    gpio_pump_area_1: int
    gpio_pump_area_2: int
    gpio_fan: int
    gpio_lights: int
    gpio_buzzer: int


def load_settings() -> Settings:
    return Settings(
        backend_url=os.getenv("BACKEND_URL", "http://localhost:8000").rstrip("/"),
        mqtt_host=os.getenv("MQTT_HOST", "localhost"),
        mqtt_port=int(os.getenv("MQTT_PORT", "1883")),
        mqtt_username=os.getenv("MQTT_USERNAME", ""),
        mqtt_password=os.getenv("MQTT_PASSWORD", ""),
        mqtt_base_topic=os.getenv("MQTT_BASE_TOPIC", "invernadero"),
        device_id=os.getenv("DEVICE_ID", "raspi-01"),
        enable_gpio=os.getenv("ENABLE_GPIO", "false").lower() == "true",
        poll_interval_seconds=int(os.getenv("POLL_INTERVAL_SECONDS", "15")),
        gpio_pump_area_1=int(os.getenv("GPIO_PUMP_AREA_1", "17")),
        gpio_pump_area_2=int(os.getenv("GPIO_PUMP_AREA_2", "27")),
        gpio_fan=int(os.getenv("GPIO_FAN", "22")),
        gpio_lights=int(os.getenv("GPIO_LIGHTS", "23")),
        gpio_buzzer=int(os.getenv("GPIO_BUZZER", "24")),
    )


class BackendClient:
    def __init__(self, base_url: str) -> None:
        self.base_url = base_url

    def post(self, path: str, payload: dict[str, Any]) -> None:
        requests.post(f"{self.base_url}{path}", json=payload, timeout=10).raise_for_status()

    def report_reading(self, payload: dict[str, Any]) -> None:
        self.post("/api/readings", payload)

    def report_event(self, payload: dict[str, Any]) -> None:
        self.post("/api/events", payload)

    def report_status(self, payload: dict[str, Any]) -> None:
        self.post("/api/system-status", payload)

    def report_actuator_log(self, payload: dict[str, Any]) -> None:
        self.post("/api/actuator-logs", payload)


class GpioController:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.available = bool(GPIO) and settings.enable_gpio
        self.pin_map = {
            "pump_area_1": settings.gpio_pump_area_1,
            "pump_area_2": settings.gpio_pump_area_2,
            "fan": settings.gpio_fan,
            "lights": settings.gpio_lights,
            "buzzer": settings.gpio_buzzer,
        }

        if self.available:
            GPIO.setmode(GPIO.BCM)
            for pin in self.pin_map.values():
                GPIO.setup(pin, GPIO.OUT)
                GPIO.output(pin, GPIO.LOW)

    def set_actuator(self, actuator: str, state: str, area: str | None = None) -> dict[str, Any]:
        pin_name = actuator
        if actuator == "pump" and area == "area_1":
            pin_name = "pump_area_1"
        elif actuator == "pump" and area == "area_2":
            pin_name = "pump_area_2"

        pin = self.pin_map.get(pin_name)
        if pin is None:
            return {"actuator": actuator, "state": state, "applied": False, "reason": "unknown_actuator"}

        if not self.available:
            return {"actuator": actuator, "state": state, "applied": True, "mode": "dry_run", "pin": pin}

        GPIO.output(pin, GPIO.HIGH if state in {"on", "auto", "manual"} else GPIO.LOW)
        return {"actuator": actuator, "state": state, "applied": True, "mode": "gpio", "pin": pin}

    def cleanup(self) -> None:
        if self.available:
            GPIO.cleanup()


class GreenhouseDevice:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.backend = BackendClient(settings.backend_url)
        self.gpio = GpioController(settings)
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        if settings.mqtt_username:
            self.client.username_pw_set(settings.mqtt_username, settings.mqtt_password)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message

    def topic(self, suffix: str) -> str:
        return f"{self.settings.mqtt_base_topic}/{suffix}"

    def on_connect(self, client: mqtt.Client, userdata: Any, flags: Any, reason_code: Any, properties: Any) -> None:
        client.subscribe([(self.topic("control/#"), 1), (self.topic("commands"), 1)])

    def on_message(self, client: mqtt.Client, userdata: Any, message: mqtt.MQTTMessage) -> None:
        try:
            payload = json.loads(message.payload.decode("utf-8"))
        except Exception:
            payload = {"raw": message.payload.decode("utf-8", errors="replace")}

        actuator = payload.get("target") or payload.get("actuator") or message.topic.rsplit("/", 1)[-1]
        state = payload.get("payload", {}).get("state") or payload.get("state") or "on"
        area = payload.get("payload", {}).get("area") or payload.get("area")

        result = self.gpio.set_actuator(actuator, state, area)
        log_payload = {
            "actuator": actuator,
            "action": state,
            "area": area,
            "source": self.settings.device_id,
            "payload": {"mqtt_topic": message.topic, "input": payload, "result": result},
        }

        try:
            self.backend.report_actuator_log(log_payload)
        except Exception as exc:
            print(f"[backend] actuator log failed: {exc}")

        try:
            self.backend.report_event(
                {
                    "event_type": "actuator_command",
                    "message": f"{actuator} -> {state}",
                    "severity": "info",
                    "area": area,
                    "source": self.settings.device_id,
                }
            )
        except Exception as exc:
            print(f"[backend] event report failed: {exc}")

        print(f"[mqtt] {message.topic} -> {result}")

    def connect(self) -> None:
        self.client.connect(self.settings.mqtt_host, self.settings.mqtt_port, keepalive=30)

    def run(self) -> None:
        self.connect()
        self.client.loop_start()
        print("[device] ready")
        try:
            while True:
                time.sleep(self.settings.poll_interval_seconds)
                try:
                    self.backend.report_status(
                        {
                            "mode": "auto",
                            "overall_state": "normal",
                            "temperature": 0,
                            "humidity": 0,
                            "soil_1": 0,
                            "soil_2": 0,
                            "light": 0,
                            "gas": 0,
                            "pump_active": False,
                            "fan_active": False,
                            "lights_active": False,
                            "buzzer_active": False,
                            "source": self.settings.device_id,
                        }
                    )
                except Exception as exc:
                    print(f"[backend] status report failed: {exc}")
        except KeyboardInterrupt:
            pass
        finally:
            self.client.loop_stop()
            self.client.disconnect()
            self.gpio.cleanup()


def main() -> None:
    GreenhouseDevice(load_settings()).run()


if __name__ == "__main__":
    main()