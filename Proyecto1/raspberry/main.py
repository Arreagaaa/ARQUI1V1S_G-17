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
import subprocess
import sys
import time
from collections import deque
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
    import pigpio  # type: ignore[import-untyped]
    _HAS_PIGPIO = True
except Exception:
    pigpio = None
    _HAS_PIGPIO = False

try:
    import adafruit_dht  # type: ignore[import-untyped]
    import board  # type: ignore[import-untyped]
    _HAS_ADA_DHT = True
except Exception:
    adafruit_dht = None
    board = None
    _HAS_ADA_DHT = False

try:
    import dht11 as dht11_lib  # type: ignore[import-untyped]
    _HAS_SZ_DHT = True
except Exception:
    dht11_lib = None
    _HAS_SZ_DHT = False

try:
    from rpi_lcd import LCD as I2CLCD  # type: ignore[import-untyped]
except Exception:
    I2CLCD = None

try:
    import adafruit_ads1x15.ads1115 as ADS  # type: ignore[import-untyped]
    from adafruit_ads1x15.analog_in import AnalogIn  # type: ignore[import-untyped]
    _ADS_CLASS = ADS.ADS1115
    _HAS_ADS = True
except Exception:
    try:
        import adafruit_ads1x15.ads1015 as ADS  # type: ignore[import-untyped]
        from adafruit_ads1x15.analog_in import AnalogIn  # type: ignore[import-untyped]
        _ADS_CLASS = ADS.ADS1015
        _HAS_ADS = True
    except Exception:
        _HAS_ADS = False
        _ADS_CLASS = None
        AnalogIn = None

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
    # ADS1115/ADS1015 ADC (I2C)
    ads_i2c_address: int


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
        # ADS1115/ADS1015 ADC (I2C)
        ads_i2c_address=int(os.getenv("ADS_I2C_ADDRESS", "0x48"), 16),
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
# ADS1115/ADS1015 ADC (I2C)
# ===================================================================

class ADS1115ADC:
    """Driver para ADS1115 (16-bit) o ADS1015 (12-bit) vía I2C."""

    def __init__(self, i2c_address: int = 0x48) -> None:
        self._ads: Any = None
        self._available = _HAS_ADS
        if not self._available:
            print("[adc] ADS1115/ADS1015 no disponible (librería no instalada)")
            return
        try:
            import busio  # type: ignore[import-untyped]
            import board  # type: ignore[import-untyped]
            i2c = busio.I2C(board.SCL, board.SDA)
            self._ads = _ADS_CLASS(i2c, address=i2c_address)
            print(f"[adc] ADS1115/ADS1015 listo en dirección 0x{i2c_address:02x}")
        except Exception as exc:
            print(f"[adc] error init: {exc}")
            self._available = False

    def read_channel(self, channel: int) -> float:
        if not self._available or self._ads is None:
            return 0.0
        try:
            return float(AnalogIn(self._ads, channel).value)
        except Exception:
            return 0.0


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
        self._buzzer_pwm: Any = None
        self._buzzer_freq: int = 2000
        self._adc_buf: dict[int, deque] = {ch: deque(maxlen=5) for ch in range(1, 4)}
        self._adc_buf_seeded: set[int] = set()

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

        # Buzzer pasivo: usar PWM en lugar de DC
        try:
            self._buzzer_pwm = GPIO.PWM(settings.gpio_buzzer, self._buzzer_freq)
        except Exception:
            self._buzzer_pwm = None

        # Entradas: botones con pull-up
        for pin in (
            settings.button_mode,
            settings.button_pump_manual,
            settings.button_lights_manual,
            settings.button_silence,
        ):
            GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)

        # Inicializar DHT11 (4 drivers: adafruit-DHT22 > pigpio > szazo > adafruit-DHT11)
        # Orden: adafruit-DHT22 tiene mejor timing en kernel 6.x que szazo
        self._dht_gpio = settings.dht_gpio
        self._dht_ada22: adafruit_dht.DHT22 | None = None  # type: ignore[valid-type]
        self._dht_pi: pigpio.pi | None = None  # type: ignore[valid-type]
        self._dht_sz: dht11_lib.DHT11 | None = None  # type: ignore[valid-type]
        self._dht_ada11: adafruit_dht.DHT11 | None = None  # type: ignore[valid-type]
        if _HAS_ADA_DHT:
            try:
                self._dht_ada22 = adafruit_dht.DHT22(  # type: ignore[attr-defined]
                    getattr(board, f"D{settings.dht_gpio}"),
                    use_pulseio=False,
                )
                print(f"[dht] adafruit-DHT22 listo en GPIO {self._dht_gpio}")
            except Exception as exc:
                print(f"[dht] adafruit-DHT22 init error: {exc}")
                self._dht_ada22 = None
        if self._dht_ada22 is None and _HAS_PIGPIO:
            try:
                self._dht_pi = pigpio.pi()  # type: ignore[attr-defined]
                print(f"[dht] pigpio listo en GPIO {self._dht_gpio}")
            except Exception as exc:
                print(f"[dht] pigpio init error: {exc}")
                self._dht_pi = None
        if self._dht_ada22 is None and self._dht_pi is None and _HAS_SZ_DHT:
            try:
                self._dht_sz = dht11_lib.DHT11(pin=self._dht_gpio)
                print(f"[dht] dht11-szazo listo en GPIO {self._dht_gpio}")
            except Exception as exc:
                print(f"[dht] szazo init error: {exc}")
        if self._dht_ada22 is None and self._dht_pi is None and self._dht_sz is None and _HAS_ADA_DHT:
            try:
                self._dht_ada11 = adafruit_dht.DHT11(  # type: ignore[attr-defined]
                    getattr(board, f"D{settings.dht_gpio}"),
                    use_pulseio=False,
                )
                print(f"[dht] adafruit-DHT11 listo en GPIO {self._dht_gpio} (bitbanging)")
            except Exception as exc:
                print(f"[dht] adafruit-DHT11 init error: {exc}")
                self._dht_ada11 = None
        if self._dht_ada22 is None and self._dht_pi is None and self._dht_sz is None and self._dht_ada11 is None:
            print("[dht] no disponible")

        # Inicializar LCD (I2C preferido, paralelo fallback)
        self._init_lcd()

        print("[gpio] inicializado en modo BCM")

    # --- LCD ------------------------------------------------------------

    def _init_lcd(self) -> None:
        if not self.available:
            return
        if I2CLCD:
            for addr in (0x27, 0x3F):
                try:
                    self._lcd_i2c = I2CLCD(address=addr, bus=1)
                    print(f"[lcd] I2C LCD listo en 0x{addr:02x}")
                    self._lcd_i2c.clear()
                    return
                except Exception as exc:
                    print(f"[lcd] I2C 0x{addr:02x}: {exc}")
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
        line1 = line1.ljust(16)[:16]
        line2 = line2.ljust(16)[:16]
        if self._lcd_i2c:
            try:
                self._lcd_i2c.clear()
                self._lcd_i2c.text(line1, 1, "left")
                self._lcd_i2c.text(line2, 2, "left")
                return
            except Exception:
                pass
        if self._lcd_parallel:
            self._lcd_parallel.text(line1[:16], 1)
            self._lcd_parallel.text(line2[:16], 2)

    # --- ADC ------------------------------------------------------------

    @property
    def adc(self) -> ADS1115ADC | None:
        if not self.available:
            return None
        if self._adc is None:
            self._adc = ADS1115ADC(self.s.ads_i2c_address)
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
            if is_on and self._buzzer_pwm is not None:
                self._buzzer_pwm.start(50)
            elif self._buzzer_pwm is not None:
                self._buzzer_pwm.stop()
                self._buzzer_pwm = None
                if self.available:
                    GPIO.cleanup(self.s.gpio_buzzer)
                    GPIO.setup(self.s.gpio_buzzer, GPIO.OUT, initial=GPIO.LOW)
                    self._buzzer_pwm = GPIO.PWM(self.s.gpio_buzzer, self._buzzer_freq)
            else:
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
        # NOTA: El buzzer NO se toca aquí. El buzzer solo se activa por:
        #   1. EMERGENCIA (backend publica control/remoto buzzer on)
        #   2. Manual (botón SILENCE o control/remoto buzzer on/off)
        # Cada ciclo de estado/global con estado no-EMERGENCIA apagaba el
        # buzzer indebidamente si el usuario lo había activado manualmente.

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

    DHT_RETRIES = 3
    DHT_RETRY_DELAY = 0.5
    DHT_MAX_CONSECUTIVE_ERRORS = 8

    def _dht_reinit(self) -> None:
        """Reinicia el sensor DHT después de errores consecutivos."""
        print("[dht] re-inicializando sensor...")
        self._dht_ada22 = None
        self._dht_pi = None
        self._dht_sz = None
        self._dht_ada11 = None
        time.sleep(1)
        if _HAS_ADA_DHT:
            try:
                self._dht_ada22 = adafruit_dht.DHT22(  # type: ignore[attr-defined]
                    getattr(board, f"D{self._dht_gpio}"),
                    use_pulseio=False,
                )
                print("[dht] adafruit-DHT22 re-inicializado")
            except Exception:
                self._dht_ada22 = None
        if self._dht_ada22 is None and _HAS_PIGPIO:
            try:
                self._dht_pi = pigpio.pi()  # type: ignore[attr-defined]
                print("[dht] pigpio re-inicializado")
            except Exception:
                self._dht_pi = None
        if self._dht_ada22 is None and self._dht_pi is None and _HAS_SZ_DHT:
            try:
                self._dht_sz = dht11_lib.DHT11(pin=self._dht_gpio)
                print("[dht] szazo re-inicializado")
            except Exception:
                self._dht_sz = None
        if self._dht_ada22 is None and self._dht_pi is None and self._dht_sz is None and _HAS_ADA_DHT:
            try:
                self._dht_ada11 = adafruit_dht.DHT11(  # type: ignore[attr-defined]
                    getattr(board, f"D{self._dht_gpio}"),
                    use_pulseio=False,
                )
                print("[dht] adafruit-DHT11 re-inicializado")
            except Exception:
                self._dht_ada11 = None

    def read_dht(self) -> tuple[float | None, float | None]:
        # Try adafruit DHT22 (best timing, may read DHT11 too)
        if self._dht_ada22 is not None:
            for attempt in range(self.DHT_RETRIES):
                try:
                    temp = self._dht_ada22.temperature
                    hum = self._dht_ada22.humidity
                    if temp is not None and hum is not None and temp > 0 and hum > 0:
                        return temp, hum
                except RuntimeError:
                    pass
                time.sleep(self.DHT_RETRY_DELAY)

        # Try pigpio (requires daemon)
        if self._dht_pi is not None:
            for attempt in range(self.DHT_RETRIES):
                try:
                    result = self._dht_pi.read_dht11(self._dht_gpio)  # type: ignore[attr-defined]
                    if isinstance(result, dict):
                        temp = float(result.get("temp", 0))
                        hum = float(result.get("hum", 0))
                        if temp > 0 and hum > 0:
                            return temp, hum
                except Exception:
                    pass
                time.sleep(self.DHT_RETRY_DELAY)

        # Try szazo dht11 (simple RPi.GPIO bitbang)
        if self._dht_sz is not None:
            for attempt in range(self.DHT_RETRIES):
                try:
                    result = self._dht_sz.read()
                    if result.is_valid() and float(result.temperature) > 5:
                        return float(result.temperature), float(result.humidity)
                except Exception:
                    pass
                time.sleep(self.DHT_RETRY_DELAY)

        # Try adafruit DHT11 (bitbanging fallback)
        if self._dht_ada11 is not None:
            for attempt in range(self.DHT_RETRIES):
                try:
                    temp = self._dht_ada11.temperature
                    hum = self._dht_ada11.humidity
                    if temp is not None and hum is not None and temp > 0 and hum > 0:
                        return temp, hum
                except RuntimeError:
                    pass
                time.sleep(self.DHT_RETRY_DELAY)

        return None, None

    def read_adc_channel(self, channel: int) -> float:
        if not self.available:
            return 0.0
        adc = self.adc
        if adc is None:
            return 0.0
        raw = adc.read_channel(channel)
        buf = self._adc_buf.get(channel)
        if buf is not None:
            if channel not in self._adc_buf_seeded:
                buf.extend([raw] * buf.maxlen)
                self._adc_buf_seeded.add(channel)
            else:
                buf.append(raw)
            return sum(buf) / len(buf)
        return raw

    # --- Limpieza -------------------------------------------------------

    def cleanup(self) -> None:
        if self._buzzer_pwm is not None:
            try:
                self._buzzer_pwm.stop()
            except Exception:
                pass
        if self._dht_pi is not None:
            try:
                self._dht_pi.stop()  # type: ignore[attr-defined]
            except Exception:
                pass
        if self._dht_ada22 is not None:
            try:
                self._dht_ada22.exit()
            except Exception:
                pass
        if self._dht_ada11 is not None:
            try:
                self._dht_ada11.exit()
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
        # Timestamp del último cambio de modo (para control/remoto y botón)
        self._last_mode_change: float = 0.0
        # Throttle para estado/global (evitar saturación: backend publica 6 por ciclo)
        self._last_global_update: float = 0.0
        self._global_update_interval: float = 1.0
        self._pending_global: dict | None = None
        # Protección contra race condition: después de una acción manual
        # (botón o control/remoto), ignorar estado/global por N segundos
        # para evitar que el backend revierta el cambio con datos obsoletos.
        self._last_manual_action: float = 0.0
        self._manual_action_cooldown: float = 5.0

        # LCD rotation
        self._lcd_cycle: int = 0
        self._lcd_last_update: float = 0.0
        self._lcd_interval: float = 3.0

        # Pump timing (30s max runtime, 15s cooldown)
        self._pump_start_time: float = 0.0
        self._pump_last_stop_time: float = 0.0

        # ARM64 Fase 2 — motor de decision
        self._arm64_prog = os.path.realpath(
            os.path.join(os.path.dirname(__file__), "..", "arm64", "fase2", "build", "live_engine")
        )
        self._arm64_proc: subprocess.Popen | None = None
        self._last_arm64_decision: dict | None = None
        self._init_arm64_motor()

    def topic(self, suffix: str) -> str:
        return f"{self.settings.mqtt_base_topic}/{suffix}"

    # --- ARM64 Fase 2: motor de decision en vivo -------------------------

    def _init_arm64_motor(self) -> None:
        if not os.path.exists(self._arm64_prog):
            print(f"[arm64] binario no encontrado: {self._arm64_prog}")
            print("[arm64] compila con: make -C ../arm64")
            return
        try:
            self._arm64_proc = subprocess.Popen(
                [self._arm64_prog],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
            )
            print(f"[arm64] motor iniciado PID {self._arm64_proc.pid}")
        except Exception as exc:
            print(f"[arm64] error al iniciar motor: {exc}")
            self._arm64_proc = None

    def _feed_to_arm64(self, readings: dict[str, float], modo: int) -> dict | None:
        if self._arm64_proc is None:
            return None
        s = self.settings
        raw_adc = {}
        if self.gpio.available and self.gpio.adc:
            for ch_name, ch_num in [("soil_1", s.soil_adc_ch1), ("soil_2", s.soil_adc_ch2),
                                     ("light", s.ldr_adc_ch), ("gas", s.mq_adc_ch)]:
                raw = self.gpio.read_adc_channel(ch_num)
                raw_adc[ch_name] = int(raw) >> 6
        else:
            raw_adc = {"soil_1": 400, "soil_2": 400, "light": 500, "gas": 100}
        temp = round(readings.get("temperature", 25))
        hum = round(readings.get("humidity", 55))
        soil1 = raw_adc.get("soil_1", 400)
        soil2 = raw_adc.get("soil_2", 400)
        luz = 1023 - raw_adc.get("light", 500)  # invertir (pull-up: oscuro=alto)
        gas = raw_adc.get("gas", 100)
        csv_line = f"{temp},{hum},{soil1},{soil2},{luz},{gas},{modo}"
        try:
            self._arm64_proc.stdin.write(f"{csv_line}\n")
            self._arm64_proc.stdin.flush()
            campos = {}
            for _ in range(7):
                linea = self._arm64_proc.stdout.readline()
                if not linea:
                    break
                linea = linea.strip()
                if "=" in linea:
                    k, _, v = linea.partition("=")
                    campos[k.strip()] = v.strip()
            if campos.get("STATUS") == "ERROR":
                print(f"[arm64] error: {campos.get('ERROR','?')} — {campos.get('DETAIL','?')}")
                return None
            if "ACTION" not in campos:
                return None
            print(f"[arm64] {campos.get('ACTION','?')} TARGET={campos.get('TARGET','?')} RISK={campos.get('RISK','?')}")
            return campos
        except Exception as exc:
            print(f"[arm64] error comunicacion: {exc}")
            self._init_arm64_motor()
            return None

    def _execute_arm64_decision(self, decision: dict) -> None:
        if self.gpio.mode != "auto":
            return
        action = decision.get("ACTION", "")
        _ALLOWED = {"ALARM_ON","GAS_WARNING","RIEGO_1_ON","RIEGO_2_ON","FAN_ON",
                    "LIGHT_ON","LED_GREEN","LED_YELLOW","NO_ACTION"}
        if action not in _ALLOWED:
            print(f"[arm64] accion no permitida: {action}")
            return
        try:
            flags = int(decision.get("VALUE", "0"))
        except ValueError:
            flags = 0
        now = time.time()

        FLAG_ALARM_ON = 1
        FLAG_GAS_WARNING = 2
        FLAG_RIEGO_1_ON = 4
        FLAG_LIGHT_ON = 8
        FLAG_FAN_ON = 16
        FLAG_BLOQUEADO = 32
        FLAG_LED_YELLOW = 64
        FLAG_LED_GREEN = 128
        FLAG_NO_ACTION = 256

        # 1. BUZZER (solo con ALARM_ON)
        self.gpio.set_actuator("buzzer", "on" if (flags & FLAG_ALARM_ON) else "off")

        # 2. FAN (ALARM_ON o GAS_WARNING o FAN_ON)
        self.gpio.set_actuator("fan", "on" if (flags & (FLAG_ALARM_ON | FLAG_GAS_WARNING | FLAG_FAN_ON)) else "off")

        # 3. LIGHTS (independiente — NO se apaga por ALARM/GAS_WARNING)
        self.gpio.set_actuator("lights", "on" if (flags & FLAG_LIGHT_ON) else "off")

        # 4. PUMP solo si RIEGO_1_ON y NO hay alarma de gas
        pump_safety_stop = bool(flags & (FLAG_ALARM_ON | FLAG_GAS_WARNING))
        if pump_safety_stop:
            if self.gpio.pump_on:
                self.gpio.set_pump_irrigation(None, False)
                self._pump_last_stop_time = now
                self._pump_start_time = 0.0
        elif flags & FLAG_RIEGO_1_ON:
            if self.gpio.pump_on:
                if self._pump_start_time > 0:
                    runtime = now - self._pump_start_time
                    if runtime > 30:
                        print(f"[pump] runtime {runtime:.0f}s > 30s, force stop")
                        self.gpio.set_pump_irrigation(None, False)
                        self._pump_last_stop_time = now
                        self._pump_start_time = 0.0
                else:
                    self._pump_start_time = now
            else:
                since_stop = (now - self._pump_last_stop_time) if self._pump_last_stop_time > 0 else 999
                if since_stop >= 15:
                    self.gpio.set_pump_irrigation("area_1", True)
                    self._pump_start_time = now
        else:
            if self.gpio.pump_on:
                self.gpio.set_pump_irrigation(None, False)
                self._pump_last_stop_time = now
                self._pump_start_time = 0.0

        # 5. STATE (prioridad: EMERGENCIA > ADVERTENCIA > NORMAL)
        if flags & FLAG_ALARM_ON:
            self.gpio.set_global_state("EMERGENCIA")
        elif flags & (FLAG_GAS_WARNING | FLAG_BLOQUEADO | FLAG_LED_YELLOW):
            self.gpio.set_global_state("ADVERTENCIA")
        elif flags & FLAG_LED_GREEN:
            self.gpio.set_global_state("NORMAL")

    def _registrar_arm64_en_mongodb(self, decision: dict, readings: dict[str, float]) -> None:
        csv_input = (f"{int(readings.get('temperature',0))},{int(readings.get('humidity',0))},"
                     f"{int(readings.get('soil_1',0))},{int(readings.get('soil_2',0))},"
                     f"{int(readings.get('light',0))},{int(readings.get('gas',0))},0")
        payload = {
            "module": "LIVE_ENGINE", "total_values": 7,
            "results": {
                "ACTION": decision.get("ACTION", ""), "TARGET": decision.get("TARGET", ""),
                "RISK": decision.get("RISK", ""), "REASON": decision.get("REASON", ""),
                "VALUE": decision.get("VALUE", "0"), "INDICATOR": decision.get("INDICATOR", "0"),
                "STATUS": decision.get("STATUS", "OK"), "INPUT": csv_input,
            },
            "input": csv_input, "column": decision.get("TARGET", ""),
            "decision": decision.get("ACTION", ""), "risk": decision.get("RISK", ""),
            "status": decision.get("STATUS", "OK"), "source": self.settings.device_id,
        }
        try:
            resp = requests.post(f"{self.settings.backend_url}/api/arm64-results", json=payload, timeout=10)
            if resp.status_code in (200, 201):
                print(f"  [arm64] registrado en MongoDB")
            else:
                print(f"  [arm64] HTTP {resp.status_code}")
        except Exception as exc:
            print(f"  [arm64] error registro: {exc}")

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

        # ARM64: ejecutar análisis en la Pi (viene del dashboard)
        if actuator == "arm64_run":
            self._handle_arm64_run()
            return

        if actuator == "arm64_historical":
            self._handle_arm64_historical(payload)
            return

        # En modo auto ignorar comandos manuales (excepto mode y automation)
        source = payload.get("source", "")
        if self.gpio.mode == "auto" and actuator != "mode" and source not in ("automation", "backend_rules"):
            return

        # Mode se maneja directamente; marcar acción manual para evitar
        # que estado/global revierta el cambio antes del cooldown.
        if actuator == "mode":
            if state in ("auto", "manual"):
                self.gpio.mode = state
                self._last_mode_change = time.time()
                self._last_manual_action = time.time()
                result = {"actuator": "mode", "state": state, "applied": True}
            else:
                result = {"actuator": "mode", "state": state, "applied": False,
                          "reason": "invalid_state"}
            self._publish_status()
        else:
            # Solo las acciones manuales descartan el estado global pendiente
            if source not in ("automation", "backend_rules"):
                self._pending_global = None
                self._last_global_update = time.time()
                self._last_manual_action = time.time()

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

    def _handle_arm64_run(self) -> None:
        print("[arm64] ejecutando módulos ARM64...")
        script_dir = os.path.dirname(os.path.abspath(__file__))
        executor = os.path.join(script_dir, "arm_executor.py")
        arm_dir = os.path.join(script_dir, "..", "arm64", "fase2")
        url = self.settings.backend_url

        try:
            result = subprocess.run(
                [sys.executable, executor, "--fetch", "--url", url, "--pi", "--dir", arm_dir],
                capture_output=True, text=True, timeout=120,
            )
            for line in result.stdout.splitlines():
                print(f"[arm64] {line}")
            if result.stderr:
                for line in result.stderr.splitlines():
                    print(f"[arm64] ERROR: {line}")
            print(f"[arm64] código de salida: {result.returncode}")
        except FileNotFoundError:
            print(f"[arm64] no encontrado: {executor}")
        except subprocess.TimeoutExpired:
            print("[arm64] timeout (120s) ejecutando módulos ARM64")
        except Exception as exc:
            print(f"[arm64] error: {exc}")

    def _handle_arm64_historical(self, mqtt_payload: dict) -> None:
        params = mqtt_payload.get("payload", mqtt_payload)
        file = params.get("file", "lecturas.csv")
        start_line = params.get("start_line", 1)
        end_line = params.get("end_line", 30)
        column = params.get("column", 1)
        ideal_value = params.get("ideal_value", 55)
        module = params.get("module", "RMSE")

        print(f"[arm64] analisis historico: {module} {file} lineas {start_line}-{end_line} columna {column}")

        script_dir = os.path.dirname(os.path.abspath(__file__))
        arm_dir = os.path.join(script_dir, "..", "arm64", "fase2")
        url = self.settings.backend_url

        executor = os.path.join(script_dir, "arm_executor.py")
        try:
            subprocess.run(
                [sys.executable, executor, "--fetch", "--url", url, "--pi", "--dir", arm_dir],
                capture_output=True, text=True, timeout=30,
            )
        except Exception:
            pass

        module_map = {
            "RMSE": ("rmse", True),
            "LINEAR_REGRESSION": ("varianza", False),
            "PREDICTION_LINEAR": ("prediccion", False),
            "ERROR_INTEGRAL": ("integrals", True),
            "LOCAL_DERIVATIVE": ("derivada", False),
        }

        if module not in module_map:
            print(f"[arm64] modulo no soportado localmente, intentando backend: {module}")
            return

        binary_name, needs_ideal = module_map[module]
        binary_path = os.path.join(arm_dir, "build", binary_name)
        csv_path = os.path.join(arm_dir, file) if not file.startswith("/") else file

        if needs_ideal:
            cmd = [binary_path, csv_path, str(start_line), str(end_line), str(column), str(ideal_value)]
        elif module == "PREDICTION_LINEAR":
            k = params.get("k", 5)
            cmd = [binary_path, csv_path, str(start_line), str(end_line), str(column), str(k)]
        else:
            cmd = [binary_path, csv_path, str(start_line), str(end_line), str(column)]

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, cwd=str(arm_dir))
            for line in result.stdout.splitlines():
                print(f"[arm64] {line}")

            data = {}
            for line in result.stdout.splitlines():
                if "=" in line:
                    k, _, v = line.partition("=")
                    data[k.strip()] = v.strip()

            if data:
                import requests
                total_values = int(data.get("COUNT", 0))
                results = {k: v for k, v in data.items() if k not in ("MODULE",)}
                try:
                    resp = requests.post(f"{url}/api/arm64-results", json={
                        "module": module,
                        "total_values": total_values,
                        "results": results,
                        "column": data.get("COLUMN"),
                        "range_start": int(data["WINDOW_START"]) if "WINDOW_START" in data else None,
                        "range_end": int(data["WINDOW_END"]) if "WINDOW_END" in data else None,
                        "status": data.get("STATUS", "OK"),
                        "source": "raspi-01",
                    }, timeout=10)
                    if resp.status_code == 200:
                        print(f"[arm64] resultado historico enviado al backend")
                except Exception as exc:
                    print(f"[arm64] error al enviar resultado: {exc}")
        except FileNotFoundError:
            print(f"[arm64] binario no encontrado: {binary_path}")
        except subprocess.TimeoutExpired:
            print("[arm64] timeout ejecutando modulo historico")
        except Exception as exc:
            print(f"[arm64] error: {exc}")

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

        # Mapear ADC (0-65535 para ADS1115 16-bit, 0-1023 para MCP3008):
        ADC_MAX = 65535.0  # ADS1115 es 16-bit; ajustar a 1023 si usás MCP3008
        #   light: invertir (mayor voltaje = más luz)
        #   soil: porcentaje, invertir (seco=0% → 100%)
        #   gas: ppm escalado
        light_norm = (ADC_MAX - light) / ADC_MAX * 100.0
        soil_1_pct = (ADC_MAX - soil_1) / ADC_MAX * 100.0
        soil_2_pct = (ADC_MAX - soil_2) / ADC_MAX * 100.0
        gas_ppm = gas / ADC_MAX * 1000.0  # 0-1000 ppm aprox

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
            self._last_mode_change = now
            self._last_manual_action = now
            clear_pending()
            self._publish_status()
            self._last_button_time = now

        elif rising("pump") and self.gpio.mode == "manual":
            clear_pending()
            self._last_manual_action = now
            new_state = not self.gpio.pump_on
            result = self.gpio.set_pump_irrigation("area_1", new_state)
            self._publish_actuator("pump", result)
            self._last_button_time = now

        elif rising("lights") and self.gpio.mode == "manual":
            clear_pending()
            self._last_manual_action = now
            new_state = not self.gpio.lights_on
            result = self.gpio.set_actuator("lights", "on" if new_state else "off")
            self._publish_actuator("lights", result)
            self._last_button_time = now

        elif rising("silence"):
            if self.gpio.buzzer_on:
                clear_pending()
                self._last_manual_action = now
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

        # NOTA sobre estado/global:
        #   - overall_state: se aplica (LEDs verde/amarillo/rojo), PERO con
        #     cooldown de 5s después de una acción manual (botón o control/remoto)
        #     para evitar race condition donde el backend re-publica un estado
        #     obsoleto y revierte el cambio que el usuario acaba de hacer.
        #   - Modo: NO se sincroniza desde estado/global (solo botón o control/remoto)
        #   - Actuadores (pump, fan, lights, buzzer): NO se sincronizan desde
        #     estado/global (misma race condition fixeada antes).

        now = time.time()
        if now - self._last_manual_action < self._manual_action_cooldown:
            return

        state = payload.get("overall_state")
        # No sobreescribir estados de ARM64 con estado del backend
        cur = self.gpio.current_state
        if cur in ("EMERGENCIA", "ADVERTENCIA") and state != cur:
            return
        if state:
            self.gpio.set_global_state(state)

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

                # Fase 2: alimentar motor ARM64 y ejecutar decision en modo auto
                modo = 0 if self.gpio.mode == "auto" else 1
                decision = self._feed_to_arm64(readings, modo)
                if decision:
                    self._execute_arm64_decision(decision)
                    self._registrar_arm64_en_mongodb(decision, readings)
                    self._last_arm64_decision = decision

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
                state = self.gpio.current_state
                state_info = getattr(self, "_last_state_info", None)
                line1, line2 = self._get_lcd_screen(readings, state, state_info)
                self.gpio.update_lcd(line1, line2)
                if now - self._lcd_last_update >= self._lcd_interval:
                    self._lcd_cycle = (self._lcd_cycle + 1) % 5
                    self._lcd_last_update = now
                self._last_state_info = {"irrigation_state": "RIEGO_ACTIVO" if self.gpio.pump_on else "RIEGO_OFF",
                                         "ventilation_state": "VENTILACION_ON" if self.gpio.fan_on else "VENTILACION_OFF"}

        except KeyboardInterrupt:
            pass
        finally:
            if self._arm64_proc and self._arm64_proc.poll() is None:
                try:
                    self._arm64_proc.stdin.close()
                except Exception:
                    pass
                try:
                    self._arm64_proc.terminate()
                    self._arm64_proc.wait(timeout=3)
                except Exception:
                    self._arm64_proc.kill()
                print("[arm64] motor detenido")
            self.client.loop_stop()
            self.client.disconnect()
            self.gpio.cleanup()


def main() -> None:
    GreenhouseDevice(load_settings()).run()


if __name__ == "__main__":
    main()
