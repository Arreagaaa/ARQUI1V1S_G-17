from functools import lru_cache

from pymongo import MongoClient

from .config import get_settings


@lru_cache(maxsize=1)
def get_client() -> MongoClient:
    settings = get_settings()
    return MongoClient(settings.mongodb_uri)


def get_database():
    settings = get_settings()
    return get_client()[settings.mongodb_db_name]


def ping_mongodb() -> bool:
    try:
        get_client().admin.command("ping")
        return True
    except Exception:
        return False


def touch_indexes() -> None:
    database = get_database()
    database.sensor_readings.create_index([("area", 1), ("recorded_at", -1)])
    database.events.create_index([("created_at", -1)])
    database.commands.create_index([("created_at", -1)])
    database.system_status.create_index([("updated_at", -1)])
    database.actuator_logs.create_index([("created_at", -1)])
