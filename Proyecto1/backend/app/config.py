from dataclasses import dataclass
from functools import lru_cache
import os
from pathlib import Path

from dotenv import load_dotenv


load_dotenv(Path(__file__).resolve().parents[1] / ".env")


@dataclass(frozen=True)
class Settings:
    mongodb_uri: str
    mongodb_db_name: str
    cors_origins: list[str]
    mqtt_host: str
    mqtt_port: int
    mqtt_username: str
    mqtt_password: str
    mqtt_base_topic: str
    enable_mqtt: bool


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    origins = os.getenv("CORS_ORIGINS", "http://localhost:5173")
    return Settings(
        mongodb_uri=os.getenv("MONGODB_URI", "mongodb://localhost:27017"),
        mongodb_db_name=os.getenv("MONGODB_DB_NAME", "invernadero_iot"),
        cors_origins=[origin.strip() for origin in origins.split(",") if origin.strip()],
        mqtt_host=os.getenv("MQTT_HOST", "localhost"),
        mqtt_port=int(os.getenv("MQTT_PORT", "1883")),
        mqtt_username=os.getenv("MQTT_USERNAME", ""),
        mqtt_password=os.getenv("MQTT_PASSWORD", ""),
        mqtt_base_topic=os.getenv("MQTT_BASE_TOPIC", "invernadero"),
        enable_mqtt=os.getenv("ENABLE_MQTT", "false").lower() == "true",
    )

