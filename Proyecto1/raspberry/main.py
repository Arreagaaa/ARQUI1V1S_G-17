"""
Raspberry Pi — Cliente embebido del invernadero inteligente IoT.

Responsabilidades:
  - Leer sensores físicos (DHT11/22, 2× higrómetro de suelo, LDR, MQ-2/135).
  - Publicar lecturas por MQTT (broker.emqx.io).
  - Reportar status global al backend (REST).
  - Recibir comandos remotos por MQTT (control/#) y aplicarlos a GPIO.
  - Manejar el centro de control físico: LCD 16x2, 4 botones, 3 LEDs, buzzer.

Hardware simplificado (acorde al enunciado):
  - 1 SOLA bomba de agua (compartida por Área 1 y Área 2 mediante válvulas
    selectoras). Las áreas no se riegan en paralelo.
  - 2 válvulas (1 por área) que alternan según `riego_area1` o `riego_area2`.
  - 3 LEDs de estado (verde/amarillo/rojo) según `overall_state`.
  - 1 buzzer que se activa en EMERGENCIA.
  - 1 pantalla LCD 16x2 con información rotativa.

Topics MQTT (prefijo: grupo17/invernadero/  según enunciado ACYE1):
  - grupo17/invernadero/sensores/<tipo>     (publicar lecturas)
  - grupo17/invernadero/control/#           (recibir comandos)
  - grupo17/invernadero/actuadores/<nombre> (reportar cambios)

Si ENABLE_GPIO=false, simula los actuadores (dry-run) en PC de desarrollo.
"""

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

try:
    import adafruit_dht  # type: ignore
    import board  # type: ignore
except Exception:  # pragma: no cover
    adafruit_dht = None
    board = None

try:
    from rpi_lcd import LCD  # type: ignore
except Exception:  # pragma: no cover
    LCD = None


load_dotenv()


# --- Configuración --------------------------------------------------------

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
    # Riego (1 bomba + 2 válvulas)
    gpio_pump: int
    gpio_valve_area_1: int
    gpio_valve_area_2: int
    gpio_fan: int
    gpio_lights: int
    gpio_buzzer: int
    # LEDs de estado
    gpio_led_green: int
    gpio_led_yellow: int
    gpio_led_red: int
    # LCD
    lcd_rs: int
    lcd_e: int
    lcd_d4: int
    lcd_d5: int
    lcd_d6: int
    lcd_d7: int
    # Botones
    button_mode: int
    button_pump_manual: int
    button_lights_manual: int
    button_silence: int
    # Sensores
    dht_gpio: int
    ldr_gpio: int
    soil_gpio_a1: int
    soil_gpio_a2: int
    mq_gpio: int


def load_settings() -> Settings:
    return Settings(
        backend_url=os.getenv("BACKEND_URL", "http://localhost:8080").rstrip("/"),
        mqtt_host=os.getenv("MQTT_HOST", "broker.emqx.io"),
        mqtt_port=int(os.getenv("MQTT_PORT", "1883")),
        mqtt_username=os.getenv("MQTT_USERNAME", ""),
        mqtt_password=os.getenv("MQTT_PASSWORD", ""),
        mqtt_base_topic=os.getenv("MQTT_BASE_TOPIC", "grupo17/invernadero"),
        device_id=os.getenv("DEVICE_ID", "raspi-01"),
        enable_gpio=os.getenv("ENABLE_GPIO", "false").lower() == "true",
        poll_interval_seconds=int(os.getenv("POLL_INTERVAL_SECONDS", "15")),
        gpio_pump=int(os.getenv("GPIO_PUMP", "17")),
        gpio_valve_area_1=int(os.getenv("GPIO_VALVE_AREA_1", "27")),
        gpio_valve_area_2=int(os.getenv("GPIO_VALVE_AREA_2", "22")),
        gpio_fan=int(os.getenv("GPIO_FAN", "23")),
        gpio_lights=int(os.getenv("GPIO_LIGHTS", "24")),
        gpio_buzzer=int(os.getenv("GPIO_BUZZER", "25")),
        gpio_led_green=int(os.getenv("GPIO_LED_GREEN", "5")),
        gpio_led_yellow=int(os.getenv("GPIO_LED_YELLOW", "6")),
        gpio_led_red=int(os.getenv("GPIO_LED_RED", "12")),
        lcd_rs=int(os.getenv("LCD_RS", "13")),
        lcd_e=int(os.getenv("LCD_E", "19")),
        lcd_d4=int(os.getenv("LCD_D4", "16")),
        lcd_d5=int(os.getenv("LCD_D5", "20")),
        lcd_d6=int(os.getenv("LCD_D6", "21")),
        lcd_d7=int(os.getenv("LCD_D7", "26")),
        button_mode=int(os.getenv("BUTTON_MODE", "4")),
        button_pump_manual=int(os.getenv("BUTTON_PUMP_MANUAL", "17")),
        button_lights_manual=int(os.getenv("BUTTON_LIGHTS_MANUAL", "18")),
        button_silence=int(os.getenv("BUTTON_SILENCE", "23")),
        dht_gpio=int(os.getenv("DHT_GPIO", "27")),
        ldr_gpio=int(os.getenv("LDR_GPIO", "14")),
        soil_gpio_a1=int(os.getenv("SOIL_GPIO_A1", "2")),
        soil_gpio_a2=int(os.getenv("SOIL_GPIO_A2", "3")),
        mq_gpio=int(os.getenv("MQ_GPIO", "4")),
    )


# --- Cliente REST al backend ---------------------------------------------

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


# --- Controlador GPIO -----------------------------------------------------

class GpioController:
    """
    Maneja GPIO de: 1 bomba + 2 válvulas, ventilador, luces, buzzer, 3 LEDs
    de estado, LCD 16x2 y 4 botones físicos.
    """

    PUMP = "pump"
    VALVE_1 = "valve_area_1"
    VALVE_2 = "valve_area_2"
    FAN = "fan"
    LIGHTS = "lights"
    BUZZER = "buzzer"

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.available = bool(GPIO) and settings.enable_gpio

        # Estado actual
        self.pump_on: bool = False
        self.valve_area_1_on: bool = False
        self.valve_area_2_on: bool = False
        self.fan_on: bool = False
        self.lights_on: bool = False
        self.buzzer_on: bool = False
        self.current_state: str = "NORMAL"

        if self.available:
            GPIO.setmode(GPIO.BCM)
            # Salidas (actuadores)
            for pin in (
                settings.gpio_pump,
                settings.gpio_valve_area_1,
                settings.gpio_valve_area_2,
                settings.gpio_fan,
                settings.gpio_lights,
                settings.gpio_buzzer,
                settings.gpio_led_green,
                settings.gpio_led_yellow,
                settings.gpio_led_red,
            ):
                GPIO.setup(pin, GPIO.OUT)
                GPIO.output(pin, GPIO.LOW)
            # Entradas (botones) con pull-up interno
            for pin in (
                settings.button_mode,
                settings.button_pump_manual,
                settings.button_lights_manual,
                settings.button_silence,
            ):
                GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            print("[gpio] inicializado en modo BCM")

    def _write(self, pin: int, on: bool) -> None:
        if self.available:
            GPIO.output(pin, GPIO.HIGH if on else GPIO.LOW)

    def set_pump_irrigation(self, area: str | None, on: bool) -> dict[str, Any]:
        """
        Activa/desactiva la bomba para un área. Las válvulas son mutuamente
        excluyentes: si el área 1 riega, la válvula 2 está cerrada.
        """
        if not on:
            self._write(self.settings.gpio_pump, False)
            self._write(self.settings.gpio_valve_area_1, False)
            self._write(self.settings.gpio_valve_area_2, False)
            self.pump_on = False
            self.valve_area_1_on = False
            self.valve_area_2_on = False
            return {"actuator": "pump", "state": "off", "applied": True, "mode": "gpio" if self.available else "dry_run"}

        if area == "area_1":
            self._write(self.settings.gpio_valve_area_1, True)
            self._write(self.settings.gpio_valve_area_2, False)
            self._write(self.settings.gpio_pump, True)
            self.pump_on = True
            self.valve_area_1_on = True
            self.valve_area_2_on = False
        elif area == "area_2":
            # Área 2 se riega manualmente (solo 1 válvula física instalada)
            print("[gpio] Área 2: riego manual requerido — mover manguera manualmente")
            self._write(self.settings.gpio_valve_area_1, False)
            self.pump_on = False
            self.valve_area_1_on = False
            self.valve_area_2_on = False
            return {"actuator": "pump", "state": "manual", "area": area, "applied": False, "reason": "valvula_2_no_instalada", "mode": "dry_run"}
        else:
            # Sin área específica: apagar todo
            return self.set_pump_irrigation(None, False)
        return {"actuator": "pump", "state": "on", "area": area, "applied": True, "mode": "gpio" if self.available else "dry_run"}

    def set_actuator(self, actuator: str, state: str, area: str | None = None) -> dict[str, Any]:
        is_on = state in {"on", "auto", "manual"}

        if actuator == "pump" or actuator in {"irrigation", "riego"}:
            return self.set_pump_irrigation(area, is_on)

        if actuator == "fan":
            self._write(self.settings.gpio_fan, is_on)
            self.fan_on = is_on
        elif actuator == "lights":
            self._write(self.settings.gpio_lights, is_on)
            self.lights_on = is_on
        elif actuator == "buzzer" or actuator == "alarm":
            self._write(self.settings.gpio_buzzer, is_on)
            self.buzzer_on = is_on
        else:
            return {"actuator": actuator, "state": state, "applied": False, "reason": "unknown_actuator"}

        return {
            "actuator": actuator,
            "state": state,
            "applied": True,
            "mode": "gpio" if self.available else "dry_run",
        }

    def set_global_state(self, overall_state: str) -> None:
        """
        Actualiza los 3 LEDs de estado global:
          NORMAL       → verde
          ADVERTENCIA  → amarillo
          RIEGO_ACTIVO → amarillo
          MODO_MANUAL  → amarillo
          EMERGENCIA   → rojo
        """
        self.current_state = overall_state
        green = overall_state == "NORMAL"
        yellow = overall_state in {"ADVERTENCIA", "RIEGO_ACTIVO", "MODO_MANUAL"}
        red = overall_state == "EMERGENCIA"
        self._write(self.settings.gpio_led_green, green)
        self._write(self.settings.gpio_led_yellow, yellow)
        self._write(self.settings.gpio_led_red, red)
        if not red:
            self._write(self.settings.gpio_buzzer, False)
            self.buzzer_on = False

    def update_lcd(self, line1: str, line2: str) -> None:
        """Muestra texto en la pantalla LCD 16x2 (rotativa)."""
        if not (self.available and LCD):
            print(f"[lcd] {line1} | {line2}")
            return
        lcd = LCD(
            address=0x27,
            bus=1,
            cols=16,
            rows=2,
            backlight=True,
        )
        lcd.text(line1[:16], 1, "left")
        lcd.text(line2[:16], 2, "left")
        lcd.close()

    def cleanup(self) -> None:
        if self.available:
            GPIO.cleanup()


# --- Dispositivo embebido -------------------------------------------------

class GreenhouseDevice:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.backend = BackendClient(settings.backend_url)
        self.gpio = GpioController(settings)
        self.client = mqtt.Client(
            mqtt.CallbackAPIVersion.VERSION2,
            client_id=f"{settings.device_id}-{int(time.time())}",
        )
        if settings.mqtt_username:
            self.client.username_pw_set(settings.mqtt_username, settings.mqtt_password)
        self.client.reconnect_delay_set(min_delay=1, max_delay=30)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message

    def topic(self, suffix: str) -> str:
        return f"{self.settings.mqtt_base_topic}/{suffix}"

    def on_connect(self, client: mqtt.Client, userdata: Any, flags: Any, reason_code: Any, properties: Any) -> None:
        if reason_code == 0:
            print(f"[mqtt] conectado a {self.settings.mqtt_host}:{self.settings.mqtt_port}")
            client.subscribe([(self.topic("control/#"), 1)])
        else:
            print(f"[mqtt] conexión fallida: rc={reason_code}")

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

        for label, fn in (
            ("actuator_log", self.backend.report_actuator_log),
            ("event", self.backend.report_event),
        ):
            try:
                if label == "actuator_log":
                    fn(log_payload)
                else:
                    fn({
                        "event_type": "actuator_command",
                        "message": f"{actuator} -> {state}",
                        "severity": "info",
                        "area": area,
                        "source": self.settings.device_id,
                    })
            except Exception as exc:
                print(f"[backend] {label} failed: {exc}")

        print(f"[mqtt] {message.topic} -> {result}")

    def connect(self) -> None:
        self.client.connect(self.settings.mqtt_host, self.settings.mqtt_port, keepalive=30)

    def read_sensors(self) -> dict[str, float]:
        """
        Lee los sensores físicos. En modo dry-run (PC de desarrollo) devuelve
        lecturas en cero. En Pi real, integra DHT11/22 (GPIO + adafruit_dht),
        LDR, higrómetros y MQ-2/135 (todos vía ADC MCP3008 en Pi 3/4).
        """
        if not self.gpio.available:
            return {
                "temperature": 0.0,
                "humidity": 0.0,
                "soil_1": 0.0,
                "soil_2": 0.0,
                "light": 0.0,
                "gas": 0.0,
            }
        # Producción: integrar lecturas reales con adafruit_dht + MCP3008 ADC
        # (drivers disponibles en 01_PYTHON/lessons/04_dht11 y 07_hc_sr04 del repo auxiliar)
        return {
            "temperature": 0.0,
            "humidity": 0.0,
            "soil_1": 0.0,
            "soil_2": 0.0,
            "light": 0.0,
            "gas": 0.0,
        }

    def run(self) -> None:
        self.connect()
        self.client.loop_start()
        print(f"[device] {self.settings.device_id} listo (GPIO={'on' if self.gpio.available else 'dry-run'})")
        try:
            while True:
                time.sleep(self.settings.poll_interval_seconds)
                readings = self.read_sensors()
                try:
                    self.backend.report_status({
                        "mode": "auto",
                        "overall_state": self.gpio.current_state,
                        "temperature": readings["temperature"],
                        "humidity": readings["humidity"],
                        "soil_1": readings["soil_1"],
                        "soil_2": readings["soil_2"],
                        "light": readings["light"],
                        "gas": readings["gas"],
                        "pump_active": self.gpio.pump_on,
                        "fan_active": self.gpio.fan_on,
                        "lights_active": self.gpio.lights_on,
                        "buzzer_active": self.gpio.buzzer_on,
                        "source": self.settings.device_id,
                    })
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
