"""
Schemas y DTOs del sistema de invernadero inteligente IoT.

Incluye:
- Modelos de entrada para la API REST (Create)
- Modelos de payload MQTT según contrato oficial
- Modelos de control remoto
- Modelos de respuesta
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator


# ---------------------------------------------------------------------------
# Sensor Readings
# ---------------------------------------------------------------------------

class SensorReadingCreate(BaseModel):
    """DTO para crear una lectura de sensor vía API REST."""

    sensor_type: str = Field(min_length=1, description="Tipo de sensor: temperature, humidity, soil_1, soil_2, light, gas")
    value: float = Field(description="Valor numérico de la lectura")
    unit: str = Field(default="", description="Unidad de medida (°C, %, ppm)")
    area: str = Field(min_length=1, description="Ubicación: area_1, area_2, control")
    status: str = Field(default="normal", description="Estado local: normal, warning, critical")
    source: str = Field(default="raspi-01", description="Identificador del dispositivo origen")
    recorded_at: Optional[datetime] = None

    @field_validator("value")
    @classmethod
    def check_value_range(cls, v: float, info) -> float:
        sensor = (info.data.get("sensor_type") or "").lower()
        if sensor in ("temperature", "temperatura"):
            if not (0 <= v <= 50):
                raise ValueError("Temperatura fuera de rango (0‑50 °C)")
        elif sensor in ("humidity", "humedad", "humedad_ambiente"):
            if not (0 <= v <= 100):
                raise ValueError("Humedad fuera de rango (0‑100 %)")
        elif sensor in ("soil_1", "soil_2", "humidity_soil_1", "humidity_soil_2",
                         "humedad_suelo_area1", "humedad_suelo_area2"):
            if not (0 <= v <= 100):
                raise ValueError("Humedad del suelo fuera de rango (0‑100 %)")
        elif sensor in ("light", "luz"):
            if not (0 <= v <= 100):
                raise ValueError("Luz fuera de rango (0‑100 %)")
        elif sensor == "gas":
            if not (0 <= v <= 500):
                raise ValueError("Gas fuera de rango (0‑500 ppm)")
        return v


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

class EventCreate(BaseModel):
    """DTO para crear un evento."""

    event_type: str = Field(min_length=1)
    message: str = Field(min_length=1)
    severity: str = Field(default="info", description="info, warning, critical")
    area: Optional[str] = None
    source: str = Field(default="raspi-01")
    created_at: Optional[datetime] = None


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

class CommandCreate(BaseModel):
    """DTO para crear un comando."""

    command: str = Field(min_length=1)
    target: str = Field(default="system")
    source: str = Field(default="web")
    payload: dict = Field(default_factory=dict)
    created_at: Optional[datetime] = None


# ---------------------------------------------------------------------------
# System Status
# ---------------------------------------------------------------------------

class SystemStatusCreate(BaseModel):
    """DTO para registrar un estado global del sistema."""

    mode: str = Field(default="auto")
    overall_state: str = Field(default="NORMAL")
    temperature: float = Field(default=0.0)
    humidity: float = Field(default=0.0)
    soil_1: float = Field(default=0.0)
    soil_2: float = Field(default=0.0)
    light: float = Field(default=0.0)
    gas: float = Field(default=0.0)
    pump_active: bool = Field(default=False)
    fan_active: bool = Field(default=False)
    lights_active: bool = Field(default=False)
    buzzer_active: bool = Field(default=False)
    source: str = Field(default="raspi-01")
    updated_at: Optional[datetime] = None


# ---------------------------------------------------------------------------
# Actuator Logs
# ---------------------------------------------------------------------------

class ActuatorLogCreate(BaseModel):
    """DTO para crear un log de actuador."""

    actuator: str = Field(min_length=1)
    action: str = Field(min_length=1)
    source: str = Field(default="web")
    area: Optional[str] = None
    payload: dict = Field(default_factory=dict)
    created_at: Optional[datetime] = None


# ---------------------------------------------------------------------------
# ARM64 Results
# ---------------------------------------------------------------------------

class ARM64ResultCreate(BaseModel):
    """DTO para almacenar resultados de módulos ARM64."""

    module: str = Field(min_length=1, description="WEIGHTED_MEAN, VARIANCE, ANOMALY_DETECTION, PREDICTION, ADVANCED_TREND")
    total_values: int = Field(default=30)
    results: dict = Field(default_factory=dict)
    source: str = Field(default="raspi-01")
    created_at: Optional[datetime] = None


# ---------------------------------------------------------------------------
# Control remoto — Endpoints específicos del enunciado
# ---------------------------------------------------------------------------

class ControlRequest(BaseModel):
    """Modelo base para solicitudes de control remoto."""

    state: str = Field(description="on, off, auto, manual, mute")
    area: Optional[str] = Field(default=None, description="area_1 o area_2 si aplica")
    source: str = Field(default="web")


class ModeChangeRequest(BaseModel):
    """Solicitud de cambio de modo auto/manual."""

    mode: str = Field(description="auto o manual")
    source: str = Field(default="web")

    @field_validator("mode")
    @classmethod
    def validate_mode(cls, v: str) -> str:
        if v not in ("auto", "manual"):
            raise ValueError("Modo inválido. Usar 'auto' o 'manual'.")
        return v


# ---------------------------------------------------------------------------
# MQTT Payloads — Contrato oficial grupo17/invernadero
# ---------------------------------------------------------------------------

class SensorMQTTPayload(BaseModel):
    """Payload MQTT para publicación de datos de sensores."""

    sensor_type: str
    value: float
    unit: str
    area: str
    status: str = "normal"
    source: str = "raspi-01"
    timestamp: Optional[datetime] = None


class ActuatorMQTTPayload(BaseModel):
    """Payload MQTT para publicación de cambios en actuadores."""

    actuator: str
    action: str
    area: Optional[str] = None
    source: str = "raspi-01"
    payload: dict = Field(default_factory=dict)
    timestamp: Optional[datetime] = None


class CommandMQTTPayload(BaseModel):
    """Payload MQTT para comandos de control remoto."""

    command: str
    target: str
    source: str = "web"
    payload: dict = Field(default_factory=dict)
    timestamp: Optional[datetime] = None


class GlobalStateMQTTPayload(BaseModel):
    """Payload MQTT para estado global del sistema."""

    mode: str = "auto"
    overall_state: str = "NORMAL"
    temperature: float = 0.0
    humidity: float = 0.0
    soil_1: float = 0.0
    soil_2: float = 0.0
    light: float = 0.0
    gas: float = 0.0
    pump_active: bool = False
    fan_active: bool = False
    lights_active: bool = False
    buzzer_active: bool = False
    source: str = "raspi-01"
    timestamp: Optional[datetime] = None
