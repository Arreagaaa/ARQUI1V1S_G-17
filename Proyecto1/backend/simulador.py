"""
Simulador de sensores para el Invernadero Inteligente IoT (Grupo 17).

Publica lecturas simuladas cada 5 segundos vía MQTT y las inserta en MongoDB local.
Soporta escenarios especiales para probar la lógica de automatización.

Uso:
    python simulador.py                    # modo normal
    python simulador.py --scenario emergencia   # forzar emergencia
    python simulador.py --scenario seco_area_1  # forzar suelo seco área 1
"""

import argparse
import json
import logging
import os
import random
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import paho.mqtt.client as mqtt
from dotenv import load_dotenv
from pymongo import MongoClient

load_dotenv(Path(__file__).resolve().parent / ".env")

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

MQTT_HOST = os.getenv("MQTT_HOST", "broker.emqx.io")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
BASE_TOPIC = os.getenv("MQTT_BASE_TOPIC", "grupo17/invernadero")
MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
DB_NAME = os.getenv("MONGODB_DB_NAME", "invernadero_iot")
CLIENT_ID = os.getenv("SIMULATOR_CLIENT_ID", "simulador_grupo17")
INTERVAL = 5

SENSOR_TOPICS = {
    "temperatura": f"{BASE_TOPIC}/sensores/temperatura",
    "humedad_ambiente": f"{BASE_TOPIC}/sensores/humedad_ambiente",
    "humedad_suelo_area1": f"{BASE_TOPIC}/sensores/humedad_suelo_area1",
    "humedad_suelo_area2": f"{BASE_TOPIC}/sensores/humedad_suelo_area2",
    "luz": f"{BASE_TOPIC}/sensores/luz",
    "gas": f"{BASE_TOPIC}/sensores/gas",
}

class SensorSimulator:
    def __init__(self, scenario=None):
        self.scenario = scenario
        self._rng = random.Random()
        self._base_temp = 25.0
        self._base_humidity = 55.0
        self._base_soil_1 = 50.0
        self._base_soil_2 = 48.0
        self._base_light = 60.0
        self._base_gas = 60.0

        self._mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=CLIENT_ID)
        self._mqtt_client.connect(MQTT_HOST, MQTT_PORT, keepalive=30)
        self._mqtt_client.loop_start()

        self._mongo_client = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=5000)
        self._db = self._mongo_client[DB_NAME]

        logger.info("Simulador conectado a MQTT %s:%s y MongoDB %s", MQTT_HOST, MQTT_PORT, MONGODB_URI)

    def _drift(self, base, min_val, max_val, step=2.0):
        delta = self._rng.uniform(-step, step)
        return max(min_val, min(max_val, base + delta))

    def _apply_scenario(self):
        if self.scenario == "emergencia":
            self._base_gas = self._rng.uniform(700, 900)
            self._base_temp = self._rng.uniform(36, 40)
        elif self.scenario == "seco_area_1":
            self._base_soil_1 = self._rng.uniform(5, 19)
        elif self.scenario == "saturado_area_2":
            self._base_soil_2 = self._rng.uniform(86, 100)
        elif self.scenario == "poca_luz":
            self._base_light = self._rng.uniform(10, 199)

    def generate_readings(self):
        self._apply_scenario()

        self._base_temp = self._drift(self._base_temp, 22, 38, 0.8)
        self._base_humidity = self._drift(self._base_humidity, 40, 90, 2.0)
        self._base_soil_1 = self._drift(self._base_soil_1, 0, 100, 3.0)
        self._base_soil_2 = self._drift(self._base_soil_2, 0, 100, 3.0)
        self._base_light = self._drift(self._base_light, 0, 1023, 10.0)
        self._base_gas = self._drift(self._base_gas, 0, 1023, 5.0)

        sensors = {
            "temperatura": (round(self._base_temp, 1), "°C", "control"),
            "humedad_ambiente": (round(self._base_humidity, 1), "%", "control"),
            "humedad_suelo_area1": (round(self._base_soil_1, 1), "%", "area_1"),
            "humedad_suelo_area2": (round(self._base_soil_2, 1), "%", "area_2"),
            "luz": (round(self._base_light, 1), "lux", "control"),
            "gas": (round(self._base_gas, 1), "ppm", "control"),
        }
        return sensors

    def publish_and_store(self):
        now = datetime.now(timezone.utc)
        sensors = self.generate_readings()

        for sensor_type, (value, unit, area) in sensors.items():
            topic = SENSOR_TOPICS[sensor_type]
            payload = {
                "sensor_type": sensor_type,
                "value": value,
                "unit": unit,
                "area": area,
                "status": "normal",
                "source": "simulador",
                "timestamp": now.isoformat(),
            }

            self._mqtt_client.publish(topic, json.dumps(payload), qos=1)

            self._db.sensor_readings.insert_one({
                "sensor_type": sensor_type,
                "value": value,
                "unit": unit,
                "area": area,
                "status": "normal",
                "source": "simulador",
                "recorded_at": now,
            })

        logger.info(
            "Publicado: T=%.1f°C H=%.1f%% S1=%.1f%% S2=%.1f%% L=%.1f lux G=%.1f ppm  [escenario: %s]",
            sensors["temperatura"][0], sensors["humedad_ambiente"][0],
            sensors["humedad_suelo_area1"][0], sensors["humedad_suelo_area2"][0],
            sensors["luz"][0], sensors["gas"][0],
            self.scenario or "ninguno",
        )

    def run(self):
        logger.info("Simulador iniciado (intervalo=%ds). Escenario: %s", INTERVAL, self.scenario or "normal")
        try:
            while True:
                self.publish_and_store()
                time.sleep(INTERVAL)
        except KeyboardInterrupt:
            logger.info("Simulador detenido por el usuario.")
        finally:
            self._mqtt_client.loop_stop()
            self._mqtt_client.disconnect()
            self._mongo_client.close()


def main():
    parser = argparse.ArgumentParser(description="Simulador de sensores IoT")
    parser.add_argument("--scenario", choices=["emergencia", "seco_area_1", "saturado_area_2", "poca_luz", "ninguno"], default=None)
    args = parser.parse_args()

    sensor_sim = SensorSimulator(scenario=args.scenario)
    sensor_sim.run()


if __name__ == "__main__":
    main()
