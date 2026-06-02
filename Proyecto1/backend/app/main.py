from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from bson import ObjectId

from .config import get_settings
from .db import get_database, ping_mongodb, touch_indexes
from .mqtt_service import publish_control_event
from .schemas import ActuatorLogCreate, CommandCreate, EventCreate, SensorReadingCreate, SystemStatusCreate


app = FastAPI(title="Invernadero Inteligente IoT API", version="0.1.0")
settings = get_settings()

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup_event():
    touch_indexes()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize_document(document: dict | None):
    if not document:
        return None
    serialized = dict(document)
    if isinstance(serialized.get("_id"), ObjectId):
        serialized["_id"] = str(serialized["_id"])
    return serialized


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "mongodb": ping_mongodb(),
        "timestamp": _now(),
    }


@app.get("/api/dashboard")
def dashboard_summary():
    db = get_database()
    latest_status = _serialize_document(db.system_status.find_one(sort=[("updated_at", -1)]))
    recent_readings = [_serialize_document(item) for item in db.sensor_readings.find().sort("recorded_at", -1).limit(8)]
    recent_events = [_serialize_document(item) for item in db.events.find().sort("created_at", -1).limit(8)]
    recent_commands = [_serialize_document(item) for item in db.commands.find().sort("created_at", -1).limit(8)]
    recent_logs = [_serialize_document(item) for item in db.actuator_logs.find().sort("created_at", -1).limit(8)]

    return {
        "status": latest_status or {
            "mode": "auto",
            "overall_state": "normal",
            "temperature": 0,
            "humidity": 0,
            "soil_1": 0,
            "soil_2": 0,
            "light": 0,
            "gas": 0,
            "pump_active": False,
            "fan_active": False,
            "lights_active": False,
            "buzzer_active": False,
            "updated_at": _now(),
        },
        "recent_readings": recent_readings,
        "recent_events": recent_events,
        "recent_commands": recent_commands,
        "recent_logs": recent_logs,
    }


@app.post("/api/readings")
def create_reading(payload: SensorReadingCreate):
    db = get_database()
    document = payload.model_dump()
    document["recorded_at"] = document["recorded_at"] or _now()
    result = db.sensor_readings.insert_one(document)
    return {"inserted_id": str(result.inserted_id), "document": document}


@app.post("/api/events")
def create_event(payload: EventCreate):
    db = get_database()
    document = payload.model_dump()
    document["created_at"] = document["created_at"] or _now()
    result = db.events.insert_one(document)
    return {"inserted_id": str(result.inserted_id), "document": document}


@app.post("/api/commands")
def create_command(payload: CommandCreate):
    db = get_database()
    document = payload.model_dump()
    document["created_at"] = document["created_at"] or _now()
    result = db.commands.insert_one(document)
    mqtt_result = publish_control_event("commands", document)
    return {
        "inserted_id": str(result.inserted_id),
        "document": document,
        "mqtt": mqtt_result.__dict__,
    }


@app.post("/api/system-status")
def upsert_system_status(payload: SystemStatusCreate):
    db = get_database()
    document = payload.model_dump()
    document["updated_at"] = document["updated_at"] or _now()
    result = db.system_status.insert_one(document)
    return {"inserted_id": str(result.inserted_id), "document": document}


@app.post("/api/actuator-logs")
def create_actuator_log(payload: ActuatorLogCreate):
    db = get_database()
    document = payload.model_dump()
    document["created_at"] = document["created_at"] or _now()
    result = db.actuator_logs.insert_one(document)
    return {"inserted_id": str(result.inserted_id), "document": document}


@app.post("/api/control/{actuator}")
def control_actuator(actuator: str, state: str, area: str | None = None):
    db = get_database()
    command_document = {
        "command": f"set_{actuator}",
        "target": actuator,
        "source": "web",
        "payload": {"state": state, "area": area},
        "created_at": _now(),
    }
    command_result = db.commands.insert_one(command_document)
    log_result = db.actuator_logs.insert_one(
        {
            "actuator": actuator,
            "action": state,
            "source": "web",
            "area": area,
            "payload": {"state": state},
            "created_at": _now(),
        }
    )
    mqtt_result = publish_control_event(f"control/{actuator}", command_document)
    return {
        "command_id": str(command_result.inserted_id),
        "log_id": str(log_result.inserted_id),
        "mqtt": mqtt_result.__dict__,
    }


@app.get("/api/readings/latest")
def latest_readings(limit: int = 12):
    db = get_database()
    return [_serialize_document(item) for item in db.sensor_readings.find().sort("recorded_at", -1).limit(limit)]


@app.get("/api/events/latest")
def latest_events(limit: int = 12):
    db = get_database()
    return [_serialize_document(item) for item in db.events.find().sort("created_at", -1).limit(limit)]


@app.get("/api/commands/latest")
def latest_commands(limit: int = 12):
    db = get_database()
    return [_serialize_document(item) for item in db.commands.find().sort("created_at", -1).limit(limit)]


@app.get("/api/actuator-logs/latest")
def latest_actuator_logs(limit: int = 12):
    db = get_database()
    return [_serialize_document(item) for item in db.actuator_logs.find().sort("created_at", -1).limit(limit)]
