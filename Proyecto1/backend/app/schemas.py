from datetime import datetime

from pydantic import BaseModel, Field


class SensorReadingCreate(BaseModel):
    area: str = Field(min_length=1)
    sensor_type: str = Field(min_length=1)
    value: float
    unit: str = Field(default="")
    status: str = Field(default="normal")
    recorded_at: datetime | None = None


class EventCreate(BaseModel):
    event_type: str = Field(min_length=1)
    message: str = Field(min_length=1)
    severity: str = Field(default="info")
    area: str | None = None
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
    updated_at: datetime | None = None


class ActuatorLogCreate(BaseModel):
    actuator: str = Field(min_length=1)
    action: str = Field(min_length=1)
    source: str = Field(default="web")
    area: str | None = None
    payload: dict = Field(default_factory=dict)
    created_at: datetime | None = None
