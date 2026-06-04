"""
simulador.py — Generador de datos simulados de sensores para pruebas sin hardware.

Publica lecturas vía MQTT (broker público broker.emqx.io) y las inserta
directamente en MongoDB local para que el dashboard y MQTTX Web las vean
en tiempo real.

Modos de operación:
  (sin argumentos)         : Ciclo normal con drift aleatorio cada 5 segundos.
  --scenario emergencia     : Fuerza gas > 700 ppm y temperatura > 36 °C.
  --scenario seco_area1     : Fuerza humidity_soil_1 < 20 %.
  --scenario saturado_area2  : Fuerza humidity_soil_2 > 85 %.
  --scenario poca_luz       : Fuerza luz < 200.
  --once                    : Publica una sola tanda y termina (no loop).
  --interval N              : Segundos entre publicaciones (default 5).
  --no-mqtt                 : Solo escribe en MongoDB, no publica.

Uso:
  python simulador.py
  python simulador.py --scenario emergencia
  python simulador.py --scenario seco_area1 --interval 2
  python simulador.py --once
"""

import argparse
import json
import logging
import random
import signal
import sys
import time
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

from app.config import get_settings
from app.db import get_database

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("simulador")


# -----------------------------------------------------------------------------
# Escenarios de inyección
# -----------------------------------------------------------------------------
SCENARIO_RANGES = {
    "emergencia": {
        "temperature": (36.0, 40.0),
        "gas": (700.0, 950.0),
    },
    "seco_area1": {
        "soil_1": (5.0, 19.0),
    },
    "saturado_area2": {
        "soil_2": (86.0, 99.0),
    },
    "poca_luz": {
        "light": (10.0, 199.0),
    },
}


class SensorSimulator:
    """Genera y publica lecturas de sensores."""

    def __init__(self, interval: float = 5.0, use_mqtt: bool = True, scenario: str | None = None):
        self.interval = interval
        self.use_mqtt = use_mqtt
        self.scenario = scenario
        self._running = True
        self._base = {
            "temperature": 26.0,
            "humidity": 60.0,
            "soil_1": 50.0,
            "soil_2": 48.0,
            "light": 55.0,
            "gas": 90.0,
        }
        settings = get_settings()
        self.base_topic = settings.mqtt_base_topic
        self.host = settings.mqtt_host
        self.port = settings.mqtt_port

        self.client = None
        if self.use_mqtt and settings.enable_mqtt:
            self.client = mqtt.Client(
                mqtt.CallbackAPIVersion.VERSION2,
                client_id=f"invernadero_simulador_g17_{random.randint(1000, 9999)}",
            )
            self.client.connect(self.host, self.port, keepalive=60)
            self.client.loop_start()
            logger.info("MQTT conectado a %s:%s (base: %s)", self.host, self.port, self.base_topic)
        else:
            logger.info("Simulador en modo SOLO MongoDB (ENABLE_MQTT=false o --no-mqtt).")

    def stop(self, *_) -> None:
        self._running = False
        if self.client:
            self.client.loop_stop()
            self.client.disconnect()
        logger.info("Simulador detenido.")
        sys.exit(0)

    def _drift(self, key: str, min_v: float, max_v: float, step: float = 2.0) -> float:
        delta = random.uniform(-step, step)
        self._base[key] = max(min_v, min(max_v, self._base[key] + delta))
        return self._base[key]

    def _apply_scenario(self) -> None:
        """Si hay un escenario activo, fuerza valores dentro del rango esperado."""
        if not self.scenario:
            return
        ranges = SCENARIO_RANGES.get(self.scenario, {})
        for key, (lo, hi) in ranges.items():
            if key in self._base:
                self._base[key] = random.uniform(lo, hi)
                logger.info("Escenario '%s' fija %s en %.1f", self.scenario, key, self._base[key])

    def _build_readings(self) -> list[dict]:
        now = datetime.now(timezone.utc).isoformat()
        return [
            {
                "sensor_type": "temperature",
                "value": round(self._drift("temperature", 18.0, 42.0, 1.5), 1),
                "unit": "°C",
                "area": "control",
                "status": "warning" if self._base["temperature"] > 30 else "normal",
                "source": "raspi-sim-01",
                "timestamp": now,
            },
            {
                "sensor_type": "humidity",
                "value": round(self._drift("humidity", 30.0, 90.0, 3.0), 1),
                "unit": "%",
                "area": "control",
                "status": "normal",
                "source": "raspi-sim-01",
                "timestamp": now,
            },
            {
                "sensor_type": "soil_1",
                "value": round(self._drift("soil_1", 5.0, 99.0, 4.0), 1),
                "unit": "%",
                "area": "area_1",
                "status": "warning" if self._base["soil_1"] < 30 else "normal",
                "source": "raspi-sim-01",
                "timestamp": now,
            },
            {
                "sensor_type": "soil_2",
                "value": round(self._drift("soil_2", 5.0, 99.0, 4.0), 1),
                "unit": "%",
                "area": "area_2",
                "status": "warning" if self._base["soil_2"] < 30 else "normal",
                "source": "raspi-sim-01",
                "timestamp": now,
            },
            {
                "sensor_type": "light",
                "value": round(self._drift("light", 5.0, 95.0, 5.0), 1),
                "unit": "%",
                "area": "control",
                "status": "normal",
                "source": "raspi-sim-01",
                "timestamp": now,
            },
            {
                "sensor_type": "gas",
                "value": round(self._drift("gas", 30.0, 950.0, 8.0), 1),
                "unit": "ppm",
                "area": "control",
                "status": "critical" if self._base["gas"] > 150 else "normal",
                "source": "raspi-sim-01",
                "timestamp": now,
            },
        ]

    def _topic_for(self, sensor_type: str) -> str:
        mapping = {
            "temperature": "sensores/temperatura",
            "humidity": "sensores/humedad_ambiente",
            "soil_1": "sensores/humedad_suelo_area1",
            "soil_2": "sensores/humedad_suelo_area2",
            "light": "sensores/luz",
            "gas": "sensores/gas",
        }
        return f"{self.base_topic}/{mapping.get(sensor_type, f'sensores/{sensor_type}')}"

    def _publish(self, reading: dict) -> None:
        if not self.client:
            return
        topic = self._topic_for(reading["sensor_type"])
        try:
            self.client.publish(topic, json.dumps(reading), qos=1)
        except Exception as exc:
            logger.warning("No se pudo publicar en %s: %s", topic, exc)

    def _persist(self, readings: list[dict]) -> None:
        try:
            db = get_database()
            docs = []
            for r in readings:
                doc = dict(r)
                doc["recorded_at"] = datetime.fromisoformat(r["timestamp"])
                docs.append(doc)
            if docs:
                db.sensor_readings.insert_many(docs)
        except Exception as exc:
            logger.error("Error persistiendo lecturas en MongoDB: %s", exc)

    def step(self) -> int:
        """Ejecuta un ciclo: aplica escenario, deriva valores, publica y persiste."""
        self._apply_scenario()
        readings = self._build_readings()
        for r in readings:
            self._publish(r)
        self._persist(readings)
        return len(readings)

    def run_forever(self) -> None:
        signal.signal(signal.SIGINT, self.stop)
        signal.signal(signal.SIGTERM, self.stop)
        logger.info(
            "Iniciando simulación: cada %.1fs%s%s",
            self.interval,
            f" — escenario: {self.scenario}" if self.scenario else "",
            " (sin MQTT)" if not self.client else "",
        )
        while self._running:
            count = self.step()
            logger.info("Publicadas %d lecturas (temp=%.1f, gas=%.1f, soil1=%.1f, soil2=%.1f, luz=%.1f)",
                        count, self._base["temperature"], self._base["gas"],
                        self._base["soil_1"], self._base["soil_2"], self._base["light"])
            time.sleep(self.interval)


def main() -> None:
    parser = argparse.ArgumentParser(description="Simulador de sensores para invernadero IoT")
    parser.add_argument("--scenario", choices=list(SCENARIO_RANGES.keys()),
                        help="Escenario de inyección de datos")
    parser.add_argument("--interval", type=float, default=5.0,
                        help="Segundos entre publicaciones (default: 5)")
    parser.add_argument("--once", action="store_true",
                        help="Publica una sola tanda y termina")
    parser.add_argument("--no-mqtt", action="store_true",
                        help="No publica vía MQTT, solo guarda en MongoDB")
    args = parser.parse_args()

    sim = SensorSimulator(interval=args.interval, use_mqtt=not args.no_mqtt, scenario=args.scenario)

    if args.once:
        n = sim.step()
        logger.info("Modo --once: publicadas %d lecturas. Saliendo.", n)
        return

    sim.run_forever()


if __name__ == "__main__":
    main()
