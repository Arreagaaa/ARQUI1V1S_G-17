"""
MQTTMockProvider — Generador de datos mock coherentes para desarrollo.

Genera datos realistas de sensores para probar el sistema completo
sin necesidad de hardware físico (Raspberry Pi, sensores, actuadores).

Los datos simulan un invernadero con:
- Temperatura: 20-35 °C con variación gradual
- Humedad ambiente: 40-80 %
- Humedad suelo: 25-85 % por área
- Luz: 10-90 % (ciclo día/noche)
- Gas: 50-200 ppm (normalmente bajo, picos esporádicos)
"""

import random
from datetime import datetime, timezone, timedelta


class MQTTMockProvider:
    """Genera datos mock coherentes para testing y demo sin hardware."""

    def __init__(self, seed: int | None = None) -> None:
        self._rng = random.Random(seed)
        self._base_temp = 25.0
        self._base_humidity = 55.0
        self._base_soil_1 = 50.0
        self._base_soil_2 = 48.0
        self._base_light = 60.0
        self._base_gas = 80.0

    def _drift(self, base: float, min_val: float, max_val: float, step: float = 2.0) -> float:
        """Genera un valor con drift gradual (random walk acotado)."""
        delta = self._rng.uniform(-step, step)
        return max(min_val, min(max_val, base + delta))

    def generate_sensor_reading(self, sensor_type: str, area: str = "control",
                                source: str = "raspi-01") -> dict:
        """Genera una lectura de sensor mock coherente."""
        now = datetime.now(timezone.utc)

        if sensor_type in ("temperature", "temperatura"):
            self._base_temp = self._drift(self._base_temp, 18.0, 38.0, 1.5)
            return {
                "sensor_type": "temperature",
                "value": round(self._base_temp, 1),
                "unit": "°C",
                "area": area,
                "status": "warning" if self._base_temp > 30 else "normal",
                "source": source,
                "timestamp": now.isoformat(),
            }

        if sensor_type in ("humidity", "humedad", "humedad_ambiente"):
            self._base_humidity = self._drift(self._base_humidity, 30.0, 90.0, 3.0)
            return {
                "sensor_type": "humidity",
                "value": round(self._base_humidity, 1),
                "unit": "%",
                "area": area,
                "status": "normal",
                "source": source,
                "timestamp": now.isoformat(),
            }

        if sensor_type in ("soil_1", "humedad_suelo_area1"):
            self._base_soil_1 = self._drift(self._base_soil_1, 20.0, 90.0, 4.0)
            return {
                "sensor_type": "soil_1",
                "value": round(self._base_soil_1, 1),
                "unit": "%",
                "area": "area_1",
                "status": "warning" if self._base_soil_1 < 30 else "normal",
                "source": source,
                "timestamp": now.isoformat(),
            }

        if sensor_type in ("soil_2", "humedad_suelo_area2"):
            self._base_soil_2 = self._drift(self._base_soil_2, 20.0, 90.0, 4.0)
            return {
                "sensor_type": "soil_2",
                "value": round(self._base_soil_2, 1),
                "unit": "%",
                "area": "area_2",
                "status": "warning" if self._base_soil_2 < 30 else "normal",
                "source": source,
                "timestamp": now.isoformat(),
            }

        if sensor_type in ("light", "luz"):
            self._base_light = self._drift(self._base_light, 0.0, 1023.0, 30.0)
            return {
                "sensor_type": "light",
                "value": round(self._base_light, 1),
                "unit": "lux",
                "area": area,
                "status": "warning" if self._base_light < 200 else "normal",
                "source": source,
                "timestamp": now.isoformat(),
            }

        if sensor_type == "gas":
            self._base_gas = self._drift(self._base_gas, 0.0, 1023.0, 30.0)
            return {
                "sensor_type": "gas",
                "value": round(self._base_gas, 1),
                "unit": "ppm",
                "area": area,
                "status": "critical" if self._base_gas > 700 else "warning" if self._base_gas > 300 else "normal",
                "source": source,
                "timestamp": now.isoformat(),
            }

        return {
            "sensor_type": sensor_type,
            "value": round(self._rng.uniform(0, 100), 1),
            "unit": "",
            "area": area,
            "status": "normal",
            "source": source,
            "timestamp": now.isoformat(),
        }

    def generate_full_reading_set(self, source: str = "raspi-01") -> list[dict]:
        """Genera un set completo de lecturas para todos los sensores."""
        readings = [
            self.generate_sensor_reading("temperature", "control", source),
            self.generate_sensor_reading("humidity", "control", source),
            self.generate_sensor_reading("soil_1", "area_1", source),
            self.generate_sensor_reading("soil_2", "area_2", source),
            self.generate_sensor_reading("light", "control", source),
            self.generate_sensor_reading("gas", "control", source),
        ]
        self._update_bases_from_readings(readings)
        return readings

    def generate_global_state(self, source: str = "raspi-01") -> dict:
        """Genera un estado global coherente basado en el estado actual de los mocks."""
        gas_critical = self._base_gas > 90
        temp_high = self._base_temp > 30
        soil_dry = self._base_soil_1 < 30 or self._base_soil_2 < 30

        if gas_critical:
            state = "EMERGENCIA"
        elif temp_high:
            state = "ADVERTENCIA"
        elif soil_dry:
            state = "RIEGO_ACTIVO"
        else:
            state = "NORMAL"

        return {
            "mode": "auto",
            "overall_state": state,
            "temperature": round(self._base_temp, 1),
            "humidity": round(self._base_humidity, 1),
            "soil_1": round(self._base_soil_1, 1),
            "soil_2": round(self._base_soil_2, 1),
            "light": round(self._base_light, 1),
            "gas": round(self._base_gas, 1),
            "pump_active": soil_dry,
            "fan_active": temp_high or gas_critical,
            "lights_active": self._base_light < 30,
            "buzzer_active": gas_critical,
            "source": source,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    def _update_bases_from_readings(self, readings: list[dict]) -> None:
        for r in readings:
            t = r.get("sensor_type", "")
            v = r.get("value", 0.0)
            if t == "temperature":
                self._base_temp = v
            elif t == "humidity":
                self._base_humidity = v
            elif t == "soil_1":
                self._base_soil_1 = v
            elif t == "soil_2":
                self._base_soil_2 = v
            elif t == "light":
                self._base_light = v
            elif t == "gas":
                self._base_gas = v

    def generate_historical_readings(self, count: int = 30, source: str = "raspi-01") -> list[dict]:
        """
        Genera una serie temporal de lecturas históricas (para poblar MongoDB).

        Args:
            count: Número de sets de lecturas a generar (cada set = 6 lecturas)
            source: Identificador del dispositivo

        Returns:
            Lista de lecturas con timestamps espaciados en el tiempo
        """
        readings = []
        base_time = datetime.now(timezone.utc) - timedelta(minutes=count * 5)

        for i in range(count):
            timestamp = base_time + timedelta(minutes=i * 5)
            reading_set = self.generate_full_reading_set(source)
            for reading in reading_set:
                reading["timestamp"] = timestamp.isoformat()
                reading["recorded_at"] = timestamp.isoformat()
                readings.append(reading)

        return readings
