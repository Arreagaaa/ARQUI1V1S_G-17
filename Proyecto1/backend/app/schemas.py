from datetime import datetime
from pydantic import validator, conint, confloat

from pydantic import BaseModel, Field


class SensorReadingCreate(BaseModel):
    @validator('value')
    def check_value_range(cls, v, values):
        sensor = values.get('sensor_type', '').lower()
        if sensor in ('temperature', 'temperatura'):
            if not (0 <= v <= 50):
                raise ValueError('Temperatura fuera de rango (0‑50°C)')
        elif sensor in ('humidity', 'humedad', 'humedad_ambiente'):
            if not (0 <= v <= 100):
                raise ValueError('Humedad fuera de rango (0‑100%)')
        elif sensor in ('soil_1', 'soil_2', 'humidity_soil_1', 'humidity_soil_2', 'humedad_suelo_area1', 'humedad_suelo_area2'):
            if not (0 <= v <= 100):
                raise ValueError('Humedad del suelo fuera de rango (0‑100%)')
        elif sensor == 'light' or sensor == 'luz':
            if not (0 <= v <= 100):
                raise ValueError('Luz fuera de rango (0‑100%)')
        elif sensor == 'gas':
            if not (0 <= v <= 500):
                raise ValueError('Gas fuera de rango (0‑500 ppm)')
        return v
    area: str = Field(min_length=1)
    sensor_type: str = Field(min_length=1)
    value: float
    unit: str = Field(default="")
    status: str = Field(default="normal")
    source: str = Field(default="raspi-01")
    recorded_at: datetime | None = None


class EventCreate(BaseModel):
    event_type: str = Field(min_length=1)
    message: str = Field(min_length=1)
    severity: str = Field(default="info")
    area: str | None = None
    source: str = Field(default="raspi-01")
    created_at: datetime | None = None


class CommandCreate(BaseModel):
    command: str = Field(min_length=1)
    target: str = Field(default="system")
    source: str = Field(default="web")
    payload: dict = Field(default_factory=dict)
    created_at: datetime | None = None


class SystemStatusCreate(BaseModel):
    mode: str = Field(default="auto")
    overall_state: str = Field(default="normal")
    temperature: float = Field(default=0)
    humidity: float = Field(default=0)
    soil_1: float = Field(default=0)
    soil_2: float = Field(default=0)
    light: float = Field(default=0)
    gas: float = Field(default=0)
    pump_active: bool = Field(default=False)
    fan_active: bool = Field(default=False)
    lights_active: bool = Field(default=False)
    buzzer_active: bool = Field(default=False)
    source: str = Field(default="raspi-01")
    updated_at: datetime | None = None


class ActuatorLogCreate(BaseModel):
    actuator: str = Field(min_length=1)
    action: str = Field(min_length=1)
    source: str = Field(default="web")
    area: str | None = None
    payload: dict = Field(default_factory=dict)
    created_at: datetime | None = None


class ARM64ResultCreate(BaseModel):
    module: str = Field(min_length=1)
    total_values: int = Field(default=30)
    results: dict = Field(default_factory=dict)
    source: str = Field(default="raspi-01")
    created_at: datetime | None = None

