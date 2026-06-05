"""
Configuración centralizada del backend.

Todas las variables de entorno se cargan aquí. Para migrar a MongoDB Atlas,
basta con cambiar MONGODB_URI en el archivo .env o en las variables de entorno
del servidor de producción.

Ejemplo Atlas:
  MONGODB_URI=mongodb+srv://<user>:<pass>@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority
"""

import logging
import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv


# Cargar .env desde la raíz del paquete backend
load_dotenv(Path(__file__).resolve().parents[1] / ".env")


@dataclass(frozen=True)
class Settings:
    """Configuración inmutable de la aplicación."""

    # --- Base de datos ---
    # Para migrar a Atlas, solo cambiar esta URI.
    mongodb_uri: str
    mongodb_db_name: str

    # --- CORS ---
    cors_origins: list[str]

    # --- MQTT (MQTTX Web / broker.emqx.io) ---
    mqtt_host: str
    mqtt_port: int
    mqtt_port_ssl: int
    mqtt_username: str
    mqtt_password: str
    mqtt_base_topic: str
    enable_mqtt: bool

    # --- Logging ---
    log_level: str


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Construye y cachea la configuración desde variables de entorno."""

    origins = os.getenv("CORS_ORIGINS", "http://localhost:5173")

    return Settings(
        # MongoDB — local por defecto, listo para Atlas
        mongodb_uri=os.getenv("MONGODB_URI", "mongodb://localhost:27017"),
        mongodb_db_name=os.getenv("MONGODB_DB_NAME", "invernadero_iot"),

        # CORS
        cors_origins=[o.strip() for o in origins.split(",") if o.strip()],

        # MQTT — broker público de desarrollo: broker.emqx.io
        mqtt_host=os.getenv("MQTT_HOST", "broker.emqx.io"),
        mqtt_port=int(os.getenv("MQTT_PORT", "1883")),
        mqtt_port_ssl=int(os.getenv("MQTT_PORT_SSL", "8883")),
        mqtt_username=os.getenv("MQTT_USERNAME", ""),
        mqtt_password=os.getenv("MQTT_PASSWORD", ""),
        mqtt_base_topic=os.getenv("MQTT_BASE_TOPIC", "grupo17/invernadero"),
        enable_mqtt=os.getenv("ENABLE_MQTT", "false").lower() == "true",

        # Logging
        log_level=os.getenv("LOG_LEVEL", "INFO"),
    )


def setup_logging() -> None:
    """Configura el sistema de logging de la aplicación."""
    settings = get_settings()
    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
