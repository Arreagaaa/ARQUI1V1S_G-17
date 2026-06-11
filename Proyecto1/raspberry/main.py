"""
Raspberry Pi — Cliente embebido del invernadero inteligente IoT.

Responsabilidades:
  - Leer sensores físicos: DHT11/22 (temp/humedad) por GPIO,
    LDR, 2× higrómetros, MQ-2/135 por ADC MCP3008 por SPI.
  - Publicar lecturas por MQTT (broker.emqx.io:1883).
  - Reportar status global al backend (REST).
  - Recibir comandos remotos por MQTT (control/#) y aplicarlos a GPIO.
  - Publicar cambios de actuadores a MQTT (actuadores/<nombre>).
  - Manejar el centro de control físico: LCD 16×2 (I2C o paralelo),
    4 botones físicos (modo, riego manual, luces, silencio),
    3 LEDs de estado según overall_state, 1 buzzer.

Hardware simplificado (acorde al enunciado):
  - 1 SOLA bomba de agua.
  - 1 válvula física real; Área 2 se marca como riego manual en el dashboard.
  - 3 LEDs de estado (verde/amarillo/rojo).
  - 1 buzzer en EMERGENCIA.
  - 1 LCD 16×2 con información rotativa.

Topics MQTT (prefijo: grupo17/invernadero/):
  - grupo17/invernadero/sensores/<tipo>     (publicar lecturas)
  - grupo17/invernadero/control/#           (recibir comandos)
  - grupo17/invernadero/actuadores/<nombre> (reportar cambios)

Si ENABLE_GPIO=false, simula actuadores y sensores (dry-run) en PC.
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

# ---------------------------------------------------------------------------
# imports opcionales Raspberry Pi (no rompen en PC de desarrollo)
# ---------------------------------------------------------------------------
try:
    import RPi.GPIO as GPIO  # type: ignore[import-untyped]
except Exception:
    GPIO = None

try:
    import adafruit_dht  # type: ignore[import-untyped]
    import board  # type: ignore[import-untyped]
except Exception:
    adafruit_dht = None
    board = None

try:
    from rpi_lcd import LCD as I2CLCD  # type: ignore[import-untyped]
except Exception:
    I2CLCD = None

try:
    import spidev  # type: ignore[import-untyped]
except Exception:
    spidev = None

load_dotenv()


# ===================================================================
# Configuración
# ===================================================================

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
    # Riego (1 bomba + 1 válvula física; Área 2 manual/simulada)
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
    # LCD (paralelo — sólo para fallback si no hay I2C backpack)
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
    ldr_adc_ch: int
    soil_adc_ch1: int
    soil_adc_ch2: int
    mq_adc_ch: int
    # SPI para MCP3008 (software bit-banging)
    spi_mosi: int
    spi_miso: int
    spi_sclk: int
    spi_ce: int


def load_settings() -> Settings:
    return Settings(
        backend_url=os.getenv("BACKEND_URL", "http://localhost:8000").rstrip("/"),
        mqtt_host=os.getenv("MQTT_HOST", "broker.emqx.io"),
        mqtt_port=int(os.getenv("MQTT_PORT", "1883")),
        mqtt_username=os.getenv("MQTT_USERNAME", ""),
        mqtt_password=os.getenv("MQTT_PASSWORD", ""),
        mqtt_base_topic=os.getenv("MQTT_BASE_TOPIC", "grupo17/invernadero"),
        device_id=os.getenv("DEVICE_ID", "raspi-01"),
        enable_gpio=os.getenv("ENABLE_GPIO", "false").lower() == "true",
        poll_interval_seconds=int(os.getenv("POLL_INTERVAL_SECONDS", "15")),
        # Actuadores
        gpio_pump=int(os.getenv("GPIO_PUMP", "17")),
        gpio_valve_area_1=int(os.getenv("GPIO_VALVE_AREA_1", "27")),
        gpio_valve_area_2=int(os.getenv("GPIO_VALVE_AREA_2", "22")),
        gpio_fan=int(os.getenv("GPIO_FAN", "23")),
        gpio_lights=int(os.getenv("GPIO_LIGHTS", "24")),
        gpio_buzzer=int(os.getenv("GPIO_BUZZER", "25")),
        # LEDs
        gpio_led_green=int(os.getenv("GPIO_LED_GREEN", "5")),
        gpio_led_yellow=int(os.getenv("GPIO_LED_YELLOW", "6")),
        gpio_led_red=int(os.getenv("GPIO_LED_RED", "12")),
        # LCD paralelo
        lcd_rs=int(os.getenv("LCD_RS", "13")),
        lcd_e=int(os.getenv("LCD_E", "19")),
        lcd_d4=int(os.getenv("LCD_D4", "16")),
        lcd_d5=int(os.getenv("LCD_D5", "20")),
        lcd_d6=int(os.getenv("LCD_D6", "21")),
        lcd_d7=int(os.getenv("LCD_D7", "0")),
        # Botones (todos en pines únicos, sin conflictos)
        button_mode=int(os.getenv("BUTTON_MODE", "4")),
        button_pump_manual=int(os.getenv("BUTTON_PUMP_MANUAL", "8")),
        button_lights_manual=int(os.getenv("BUTTON_LIGHTS_MANUAL", "18")),
        button_silence=int(os.getenv("BUTTON_SILENCE", "15")),
        # Sensores
        dht_gpio=int(os.getenv("DHT_GPIO", "26")),
        ldr_adc_ch=int(os.getenv("LDR_ADC_CH", "0")),
        soil_adc_ch1=int(os.getenv("SOIL_ADC_CH1", "1")),
        soil_adc_ch2=int(os.getenv("SOIL_ADC_CH2", "2")),
        mq_adc_ch=int(os.getenv("MQ_ADC_CH", "3")),
        # SPI para MCP3008 (bit-bang)
        spi_mosi=int(os.getenv("SPI_MOSI", "10")),
        spi_miso=int(os.getenv("SPI_MISO", "9")),
        spi_sclk=int(os.getenv("SPI_SCLK", "11")),
        spi_ce=int(os.getenv("SPI_CE", "7")),
    )


# ===================================================================
# Cliente REST al backend
# ===================================================================

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


# ===================================================================
# MCP3008 ADC (software SPI bit-banging con RPi.GPIO)
# ===================================================================

class MCP3008:
    """Driver MCP3008 10-bit ADC vía software SPI bit-banging."""

    def __init__(self, mosi: int, miso: int, sclk: int, ce: int) -> None:
        self._mosi = mosi
        self._miso = miso
        self._sclk = sclk
        self._ce = ce
        if GPIO and self._has_gpio:
            for p in (mosi, sclk, ce):
                GPIO.setup(p, GPIO.OUT, initial=GPIO.LOW)
            GPIO.setup(miso, GPIO.IN)

    @property
    def _has_gpio(self) -> bool:
        return GPIO is not None

    def _spi_transfer(self, byte_out: int) -> int:
        byte_in = 0
        for i in range(7, -1, -1):
            GPIO.output(self._sclk, GPIO.LOW)
            GPIO.output(self._mosi, GPIO.HIGH if (byte_out >> i) & 1 else GPIO.LOW)
            time.sleep(0.000001)
            GPIO.output(self._sclk, GPIO.HIGH)
            if GPIO.input(self._miso):
                byte_in |= 1 << i
            time.sleep(0.000001)
        return byte_in

    def read_channel(self, channel: int) -> int:
        if channel < 0 or channel > 7:
            raise ValueError(f"Canal ADC inválido: {channel}")
        GPIO.output(self._ce, GPIO.LOW)
        # comando MCP3008: start=1, single=1, canal en bits 2-4
        cmd = 0x18 | (channel & 0x07)  # 0001 1000 | canal (3 bits)
        self._spi_transfer(cmd)
        high = self._spi_transfer(0x00) & 0x03
        low = self._spi_transfer(0x00)
        GPIO.output(self._ce, GPIO.HIGH)
        return (high << 8) | low


# ===================================================================
# LCD 16×2 — controlador paralelo HD44780 (fallback si no hay I2C)
# ===================================================================

class ParallelLCD:
    """HD44780 en modo 4 bits via GPIO directo."""

    _CMD_CLEAR = 0x01
    _CMD_HOME = 0x02
    _CMD_ENTRY_MODE = 0x06
    _CMD_DISPLAY_ON = 0x0C
    _ROW_ADDR = {1: 0x00, 2: 0x40}

    def __init__(self, rs: int, e: int, d4: int, d5: int, d6: int, d7: int) -> None:
        self._pins = (rs, e, d4, d5, d6, d7)
        if GPIO:
            for pin in self._pins:
                GPIO.setup(pin, GPIO.OUT, initial=GPIO.LOW)
        self._init_4bit()

    def _pulse_e(self) -> None:
        GPIO.output(self._pins[1], True)
        time.sleep(0.000001)
        GPIO.output(self._pins[1], False)
        time.sleep(0.000001)

    def _write_nibble(self, nibble: int, is_command: bool) -> None:
        rs, e, d4, d5, d6, d7 = self._pins
        GPIO.output(rs, not is_command)
        GPIO.output(d4, bool(nibble & 1))
        GPIO.output(d5, bool(nibble & 2))
        GPIO.output(d6, bool(nibble & 4))
        GPIO.output(d7, bool(nibble & 8))
        self._pulse_e()

    def _write_byte(self, byte: int, is_command: bool) -> None:
        self._write_nibble((byte >> 4) & 0x0F, is_command)
        self._write_nibble(byte & 0x0F, is_command)

    def _init_4bit(self) -> None:
        self._write_nibble(0x03, True)
        time.sleep(0.0041)
        self._write_nibble(0x03, True)
        time.sleep(0.0001)
        self._write_nibble(0x03, True)
        self._write_nibble(0x02, True)
        self._write_byte(self._CMD_ENTRY_MODE, True)
        self._write_byte(self._CMD_DISPLAY_ON, True)
        self._write_byte(self._CMD_CLEAR, True)
        time.sleep(0.002)

    def text(self, text: str, row: int, align: str = "left") -> None:
        addr = self._ROW_ADDR.get(row, 0x00)
        self._write_byte(0x80 | addr, True)
        for ch in text[:16]:
            self._write_byte(ord(ch), False)

    def clear(self) -> None:
        self._write_byte(self._CMD_CLEAR, True)
        time.sleep(0.002)

    def close(self) -> None:
        self.clear()


# ===================================================================
# Controlador GPIO
# ===================================================================

class GpioController:
    """
    Maneja todos los GPIO: actuadores, LEDs, LCD, botones, ADC.
    """

    PUMP = "pump"
    VALVE_1 = "valve_area_1"
    VALVE_2 = "valve_area_2"
    FAN = "fan"
    LIGHTS = "lights"
    BUZZER = "buzzer"

    def __init__(self, settings: Settings) -> None:
        self.s = settings
        self.available = bool(GPIO) and settings.enable_gpio

        # Estados
        self.pump_on: bool = False
        self.valve_area_1_on: bool = False
        self.valve_area_2_on: bool = False
        self.fan_on: bool = False
        self.lights_on: bool = False
        self.buzzer_on: bool = False
        self.current_state: str = "NORMAL"
        self.mode: str = "auto"  # auto | manual

        # ADC, DHT & LCD (inicializados bajo demanda)
        self._adc: MCP3008 | None = None
        self._dht: Any = None
        self._lcd_i2c: Any = None
        self._lcd_parallel: ParallelLCD | None = None

        if not self.available:
            print("[gpio] dry-run mode (sin GPIO real)")
            return

        GPIO.setmode(GPIO.BCM)

        # Salidas: actuadores
        for pin in (
            settings.gpio_pump,
            settings.gpio_valve_area_1,
            settings.gpio_valve_area_2,
            settings.gpio_fan,
            settings.gpio_lights,
            settings.gpio_buzzer,
        ):
            GPIO.setup(pin, GPIO.OUT, initial=GPIO.LOW)

        # Salidas: LEDs
        for pin in (
            settings.gpio_led_green,
            settings.gpio_led_yellow,
            settings.gpio_led_red,
        ):
            GPIO.setup(pin, GPIO.OUT, initial=GPIO.LOW)

        # Entradas: botones con pull-up
        for pin in (
            settings.button_mode,
            settings.button_pump_manual,
            settings.button_lights_manual,
            settings.button_silence,
        ):
            GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)

        # Inicializar DHT11 (una sola instancia)
        if adafruit_dht and board:
            try:
                self._dht = adafruit_dht.DHT11(getattr(board, f"D{settings.dht_gpio}"))
            except Exception as exc:
                print(f"[dht] init error: {exc}")

        # Inicializar LCD (I2C preferido, paralelo fallback)
        self._init_lcd()

        print("[gpio] inicializado en modo BCM")

    # --- LCD ------------------------------------------------------------

    def _init_lcd(self) -> None:
        if not self.available:
            return
        if I2CLCD:
            try:
                self._lcd_i2c = I2CLCD(address=0x27, bus=1)
                print("[lcd] I2C LCD listo")
                return
            except Exception as exc:
                print(f"[lcd] I2C no disponible ({exc}), probando paralelo...")
        # Fallback a paralelo
        self._lcd_parallel = ParallelLCD(
            self.s.lcd_rs, self.s.lcd_e,
            self.s.lcd_d4, self.s.lcd_d5, self.s.lcd_d6, self.s.lcd_d7,
        )
        print("[lcd] LCD paralelo HD44780 listo")

    def update_lcd(self, line1: str, line2: str) -> None:
        if not self.available:
            print(f"[lcd] {line1} | {line2}")
            return
        if self._lcd_i2c:
            try:
                self._lcd_i2c.text(line1[:16], 1, "left")
                self._lcd_i2c.text(line2[:16], 2, "left")
                return
            except Exception:
                pass
        if self._lcd_parallel:
            self._lcd_parallel.text(line1[:16], 1)
            self._lcd_parallel.text(line2[:16], 2)

    # --- ADC ------------------------------------------------------------

    @property
    def adc(self) -> MCP3008 | None:
        if not self.available:
            return None
        if self._adc is None:
            self._adc = MCP3008(self.s.spi_mosi, self.s.spi_miso, self.s.spi_sclk, self.s.spi_ce)
        return self._adc

    # --- Actuadores -----------------------------------------------------

    def _write(self, pin: int, on: bool) -> None:
        if self.available:
            GPIO.output(pin, GPIO.HIGH if on else GPIO.LOW)

    def set_pump_irrigation(self, area: str | None, on: bool) -> dict[str, Any]:
        if not on:
            self._write(self.s.gpio_pump, False)
            self._write(self.s.gpio_valve_area_1, False)
            self._write(self.s.gpio_valve_area_2, False)
            self.pump_on = False
            self.valve_area_1_on = False
            self.valve_area_2_on = False
            return {"actuator": "pump", "state": "off", "applied": True,
                    "mode": "gpio" if self.available else "dry_run"}

        if area == "area_1":
            self._write(self.s.gpio_valve_area_1, True)
            self._write(self.s.gpio_valve_area_2, False)
            self._write(self.s.gpio_pump, True)
            self.pump_on = True
            self.valve_area_1_on = True
            self.valve_area_2_on = False
        elif area == "area_2":
            print("[gpio] Área 2: riego manual — mover manguera manualmente")
            self._write(self.s.gpio_valve_area_1, False)
            self.pump_on = False
            self.valve_area_1_on = False
            self.valve_area_2_on = False
            return {"actuator": "pump", "state": "manual", "area": area,
                    "applied": False, "reason": "valvula_2_no_instalada",
                    "mode": self._mode_str}
        else:
            # Sin válvula — solo enciende la bomba (caso automatización sin área)
            self._write(self.s.gpio_pump, True)
            self.pump_on = True
        return {"actuator": "pump", "state": "on", "area": area, "applied": True,
                "mode": self._mode_str}

    def set_actuator(self, actuator: str, state: str, area: str | None = None) -> dict[str, Any]:
        is_on = state in {"on", "auto", "manual"}

        if actuator in {"pump", "irrigation", "riego"}:
            return self.set_pump_irrigation(area, is_on)

        if actuator == "fan":
            self._write(self.s.gpio_fan, is_on)
            self.fan_on = is_on
        elif actuator == "lights":
            self._write(self.s.gpio_lights, is_on)
            self.lights_on = is_on
        elif actuator in {"buzzer", "alarm"}:
            self._write(self.s.gpio_buzzer, is_on)
            self.buzzer_on = is_on
        else:
            return {"actuator": actuator, "state": state, "applied": False,
                    "reason": "unknown_actuator"}

        return {"actuator": actuator, "state": state, "applied": True,
                "mode": self._mode_str}

    @property
    def _mode_str(self) -> str:
        return "gpio" if self.available else "dry_run"

    def set_global_state(self, overall_state: str) -> None:
        self.current_state = overall_state
        green = overall_state == "NORMAL"
        yellow = overall_state in {"ADVERTENCIA", "RIEGO_ACTIVO", "MODO_MANUAL"}
        red = overall_state == "EMERGENCIA"
        self._write(self.s.gpio_led_green, green)
        self._write(self.s.gpio_led_yellow, yellow)
        self._write(self.s.gpio_led_red, red)
        if not red:
            self._write(self.s.gpio_buzzer, False)
            self.buzzer_on = False

    # --- Botones --------------------------------------------------------

    BUTTON_DEBOUNCE_S = 0.25

    def read_buttons(self) -> dict[str, bool]:
        """
        Lee el estado actual de los 4 botones (False = presionado
        porque usamos pull-up: LOW = presionado).
        """
        if not self.available:
            return {"mode": False, "pump": False, "lights": False, "silence": False}
        return {
            "mode": not GPIO.input(self.s.button_mode),
            "pump": not GPIO.input(self.s.button_pump_manual),
            "lights": not GPIO.input(self.s.button_lights_manual),
            "silence": not GPIO.input(self.s.button_silence),
        }

    # --- Sensores -------------------------------------------------------

    def read_dht(self) -> tuple[float | None, float | None]:
        if self._dht is None:
            return None, None
        try:
            temp = self._dht.temperature
            hum = self._dht.humidity
            return temp, hum
        except Exception as exc:
            print(f"[dht] error: {exc}")
            return None, None

    def read_adc_channel(self, channel: int) -> float:
        if not self.available:
            return 0.0
        adc = self.adc
        if adc is None:
            return 0.0
        raw = adc.read_channel(channel)
        # MCP3008 retorna 0-1023
        return float(raw)

    # --- Limpieza -------------------------------------------------------

    def cleanup(self) -> None:
        if self._dht:
            try:
                self._dht.exit()
            except Exception:
                pass
        if self.available:
            GPIO.cleanup()


# ===================================================================
# Dispositivo embebido
# ===================================================================

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
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message

        # Debounce de botones
        self._last_button_time: float = 0.0
        self._last_btn_state: dict[str, bool] = {"mode": False, "pump": False, "lights": False, "silence": False}
        # Throttle para estado/global (evitar saturación: backend publica 6 por ciclo)
        self._last_global_update: float = 0.0
        self._global_update_interval: float = 1.0
        self._pending_global: dict | None = None

        # LCD rotation
        self._lcd_cycle: int = 0
        self._lcd_last_update: float = 0.0
        self._lcd_interval: float = 3.0

    def topic(self, suffix: str) -> str:
        return f"{self.settings.mqtt_base_topic}/{suffix}"

    # --- MQTT callbacks ------------------------------------------------

    def _on_connect(self, client: mqtt.Client, userdata: Any, flags: Any,
                    reason_code: Any, properties: Any) -> None:
        if reason_code == 0:
            print(f"[mqtt] conectado a {self.settings.mqtt_host}:{self.settings.mqtt_port}")
            client.subscribe([
                (self.topic("control/#"), 1),
                (self.topic("estado/global"), 1),
                (self.topic("actuadores/riego_area1"), 1),
                (self.topic("actuadores/riego_area2"), 1),
            ])
            self._publish_status()
        else:
            print(f"[mqtt] conexión fallida: rc={reason_code}")

    def _on_message(self, client: mqtt.Client, userdata: Any, message: mqtt.MQTTMessage) -> None:
        try:
            payload = json.loads(message.payload.decode("utf-8"))
        except Exception:
            payload = {"raw": message.payload.decode("utf-8", errors="replace")}

        # Si el backend publica un cambio de estado global, actualizar LEDs y actuadores
        if message.topic.endswith("estado/global"):
            self._pending_global = payload
            return

        actuator = (payload.get("target") or payload.get("actuator")
                    or message.topic.rsplit("/", 1)[-1])
        state = (payload.get("payload", {}).get("state")
                 or payload.get("state")
                 or payload.get("action")
                 or "on")
        area = payload.get("payload", {}).get("area") or payload.get("area")

        # En modo auto ignorar comandos manuales (excepto mode)
        if self.gpio.mode == "auto" and actuator != "mode":
            return

        # Descartar estado global pendiente: un comando directo tiene prioridad
        self._pending_global = None
        self._last_global_update = time.time()

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

        # Publicar cambio de actuador por MQTT
        self._publish_actuator(actuator, result)
        print(f"[mqtt] {message.topic} -> {result}")

    # --- Publicaciones MQTT --------------------------------------------

    SENSOR_TOPIC_MAP = {
        "temperature": "temperatura",
        "humidity": "humedad_ambiente",
        "soil_1": "humedad_suelo_area1",
        "soil_2": "humedad_suelo_area2",
        "light": "luz",
        "gas": "gas",
    }

    ACTUATOR_TOPIC_MAP = {
        "pump": "riego",
        "fan": "ventilador",
        "lights": "luces",
        "buzzer": "alarma",
        "alarm": "alarma",
    }

    def _publish_sensor(self, sensor_type: str, value: float) -> None:
        topic_name = self.SENSOR_TOPIC_MAP.get(sensor_type, sensor_type)
        topic = self.topic(f"sensores/{topic_name}")
        payload = json.dumps({
            "sensor_type": sensor_type,
            "value": value,
            "unit": self._sensor_unit(sensor_type),
            "source": self.settings.device_id,
        })
        self.client.publish(topic, payload, qos=1)
        print(f"[mqtt] publicado {topic}: {value}")

    def _publish_actuator(self, name: str, result: dict[str, Any]) -> None:
        topic_name = self.ACTUATOR_TOPIC_MAP.get(name, name)
        topic = self.topic(f"actuadores/{topic_name}")
        payload = json.dumps({
            "actuator": name,
            "state": result.get("state", "unknown"),
            "applied": result.get("applied", False),
            "source": self.settings.device_id,
        })
        self.client.publish(topic, payload, qos=1)
        print(f"[mqtt] publicado {topic}: {result.get('state')}")

    def _publish_status(self) -> None:
        topic = self.topic("estado/global")
        payload = json.dumps({
            "mode": self.gpio.mode,
            "overall_state": self.gpio.current_state,
            "device_id": self.settings.device_id,
        })
        self.client.publish(topic, payload, qos=1, retain=True)

    @staticmethod
    def _sensor_unit(sensor_type: str) -> str:
        return {
            "temperature": "°C",
            "humidity": "%",
            "soil_1": "%",
            "soil_2": "%",
            "light": "lux",
            "gas": "ppm",
        }.get(sensor_type, "")

    # --- LCD Rotation ---------------------------------------------------

    def _get_lcd_screen(self, readings: dict[str, float], state: str, state_info: dict | None = None) -> tuple[str, str]:
        irr = (state_info or {}).get("irrigation_state", "?")
        vent = (state_info or {}).get("ventilation_state", "?")
        irr_short = irr.replace("BLOQUEADO_POR_SATURACION", "BLOQxSAT").replace("RIEGO_", "R:")
        vent_short = vent.replace("VENTILACION_", "V:")
        LINES = [
            (f"T:{readings['temperature']:.1f}C", f"H:{readings['humidity']:.0f}%"),
            (f"S1:{readings['soil_1']:.0f}% S2:{readings['soil_2']:.0f}%", f"Luz:{readings['light']:.0f}%"),  # noqa: E501
            (f"Luz:{readings['light']:.0f}%", f"Gas:{readings['gas']:.0f}ppm"),
            (f"{irr_short[:14]}", f"{vent_short[:14]}"),
            (f"State:{state[:12]}", f"Mode:{self.gpio.mode}"),
        ]
        if state == "EMERGENCIA":
            self._lcd_cycle = 0
            return ("!! EMERGENCIA !!", f"Gas:{readings['gas']:.0f}ppm")
        self._lcd_cycle = self._lcd_cycle % len(LINES)
        return LINES[self._lcd_cycle]

    # --- Lectura de sensores -------------------------------------------

    def read_sensors(self) -> dict[str, float]:
        s = self.settings
        gpio_ok = self.gpio.available

        # DHT11
        temp, hum = self.gpio.read_dht() if gpio_ok else (None, None)

        # ADC MCP3008
        light = self.gpio.read_adc_channel(s.ldr_adc_ch) if gpio_ok else 0.0
        soil_1 = self.gpio.read_adc_channel(s.soil_adc_ch1) if gpio_ok else 0.0
        soil_2 = self.gpio.read_adc_channel(s.soil_adc_ch2) if gpio_ok else 0.0
        gas = self.gpio.read_adc_channel(s.mq_adc_ch) if gpio_ok else 0.0

        # Mapear ADC (0-1023):
        #   light: invertir → 1023-valor (mayor voltaje = más luz)
        #   soil: porcentaje (0-1023 → 0-100%), invertir (seco=0%→100%)
        #   gas: ppm (directo, escalado)
        light_norm = (1023.0 - light) / 1023.0 * 100.0
        soil_1_pct = (1023.0 - soil_1) / 1023.0 * 100.0
        soil_2_pct = (1023.0 - soil_2) / 1023.0 * 100.0
        gas_ppm = gas / 1023.0 * 1000.0  # 0-1000 ppm aprox

        return {
            "temperature": temp or 0.0,
            "humidity": hum or 0.0,
            "soil_1": round(soil_1_pct, 1),
            "soil_2": round(soil_2_pct, 1),
            "light": round(light_norm, 1),
            "gas": round(gas_ppm, 1),
        }

    # --- Manejo de botones ---------------------------------------------

    BUTTON_COOLDOWN = 1.0

    def _handle_buttons(self) -> None:
        now = time.time()
        if now - self._last_button_time < self.BUTTON_COOLDOWN:
            return

        btns = self.gpio.read_buttons()

        # Detección de flanco de subida (False→True): solo dispara al presionar, no al mantener
        def rising(key: str) -> bool:
            return btns[key] and not self._last_btn_state[key]

        # Descarta estado global pendiente para que no sobreescriba el comando manual
        def clear_pending():
            self._pending_global = None
            self._last_global_update = time.time()

        if rising("mode"):
            self.gpio.mode = "manual" if self.gpio.mode == "auto" else "auto"
            print(f"[boton] modo -> {self.gpio.mode}")
            self._publish_status()
            self._last_button_time = now

        elif rising("pump") and self.gpio.mode == "manual":
            clear_pending()
            new_state = not self.gpio.pump_on
            result = self.gpio.set_pump_irrigation("area_1", new_state)
            self._publish_actuator("pump", result)
            self._last_button_time = now

        elif rising("lights") and self.gpio.mode == "manual":
            clear_pending()
            new_state = not self.gpio.lights_on
            result = self.gpio.set_actuator("lights", "on" if new_state else "off")
            self._publish_actuator("lights", result)
            self._last_button_time = now

        elif rising("silence"):
            if self.gpio.buzzer_on:
                clear_pending()
                self.gpio.set_actuator("buzzer", "off")
                print("[boton] buzzer silenciado")
                self._last_button_time = now

        self._last_btn_state = btns

    def _apply_pending_global(self) -> None:
        now = time.time()
        if now - self._last_global_update < self._global_update_interval:
            return
        if self._pending_global is None:
            return
        payload = self._pending_global
        self._pending_global = None
        self._last_global_update = now

        # Sincronizar modo desde el backend (dashboard cambió modo)
        backend_mode = payload.get("mode")
        if backend_mode in ("auto", "manual"):
            if self.gpio.mode != backend_mode:
                self.gpio.mode = backend_mode
                print(f"[estado] modo sincronizado desde backend -> {backend_mode}")

        state = payload.get("overall_state")
        if state:
            self.gpio.set_global_state(state)
        irr_state = payload.get("irrigation_state", "")
        area = "area_1" if "AREA_1" in irr_state else ("area_2" if "AREA_2" in irr_state else None)
        act_map = {
            "fan_active": ("fan", "on" if payload.get("fan_active") else "off"),
            "pump_active": ("pump", "on" if payload.get("pump_active") else "off"),
            "lights_active": ("lights", "on" if payload.get("lights_active") else "off"),
            "buzzer_active": ("buzzer", "on" if payload.get("buzzer_active") else "off"),
        }
        for key, (actuator, act_state) in act_map.items():
            if key in payload:
                self.gpio.set_actuator(actuator, act_state, area)

    # --- Loop principal ------------------------------------------------

    def connect(self) -> None:
        self.client.connect(self.settings.mqtt_host, self.settings.mqtt_port, keepalive=30)

    def run(self) -> None:
        self.connect()
        self.client.loop_start()
        print(f"[device] {self.settings.device_id} listo "
              f"(GPIO={'on' if self.gpio.available else 'dry-run'})")

        last_sensor_read = 0.0

        try:
            while True:
                time.sleep(0.1)
                self._handle_buttons()
                self._apply_pending_global()

                now = time.time()
                if now - last_sensor_read < self.settings.poll_interval_seconds:
                    continue
                last_sensor_read = now

                readings = self.read_sensors()

                # Publicar cada sensor por MQTT
                for key in ("temperature", "humidity", "soil_1", "soil_2", "light", "gas"):
                    self._publish_sensor(key, readings[key])

                # Reportar status al backend
                try:
                    self.backend.report_status({
                        "mode": self.gpio.mode,
                        "overall_state": self.gpio.current_state,
                        **readings,
                        "pump_active": self.gpio.pump_on,
                        "fan_active": self.gpio.fan_on,
                        "lights_active": self.gpio.lights_on,
                        "buzzer_active": self.gpio.buzzer_on,
                        "source": self.settings.device_id,
                    })
                except Exception as exc:
                    print(f"[backend] status report failed: {exc}")

                # Actualizar LCD con rotación cada 3s
                now = time.time()
                if now - self._lcd_last_update >= self._lcd_interval:
                    self._lcd_cycle += 1
                    self._lcd_last_update = now
                state = self.gpio.current_state
                state_info = getattr(self, "_last_state_info", None)
                line1, line2 = self._get_lcd_screen(readings, state, state_info)
                self.gpio.update_lcd(line1, line2)
                self._last_state_info = {"irrigation_state": "RIEGO_ACTIVO" if self.gpio.pump_on else "RIEGO_OFF",
                                         "ventilation_state": "VENTILACION_EMERGENCIA" if state == "EMERGENCIA" else ("VENTILACION_ON" if self.gpio.fan_on else "VENTILACION_OFF")}

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
