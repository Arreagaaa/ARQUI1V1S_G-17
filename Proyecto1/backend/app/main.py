from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from bson import ObjectId

from .config import get_settings
from .db import get_database, ping_mongodb, touch_indexes
from .mqtt_service import publish_control_event
from .schemas import ActuatorLogCreate, CommandCreate, EventCreate, SensorReadingCreate, SystemStatusCreate, ARM64ResultCreate


app = FastAPI(
    title="Invernadero Inteligente IoT API",
    description="API de monitoreo y control para el sistema de invernadero inteligente (PRE-ARM y PRE-MAQUETA)",
    version="0.2.0"
)

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


def update_latest_system_status(updates: dict) -> dict:
    db = get_database()
    latest = db.system_status.find_one(sort=[("updated_at", -1)])
    if latest:
        new_status = dict(latest)
        new_status.pop("_id", None)
        new_status.update(updates)
        new_status["updated_at"] = _now()
    else:
        new_status = {
            "mode": "auto",
            "overall_state": "NORMAL",
            "temperature": 0.0,
            "humidity": 0.0,
            "soil_1": 0.0,
            "soil_2": 0.0,
            "light": 0.0,
            "gas": 0.0,
            "pump_active": False,
            "fan_active": False,
            "lights_active": False,
            "buzzer_active": False,
            "source": "api",
            "updated_at": _now(),
        }
        new_status.update(updates)
    db.system_status.insert_one(new_status)
    return new_status


@app.get("/api/health", tags=["Sistema"])
def health():
    return {
        "status": "ok",
        "mongodb": ping_mongodb(),
        "timestamp": _now(),
    }



@app.get("/api/dashboard", tags=["Dashboard"])
def dashboard_summary():
    db = get_database()
    latest_status = _serialize_document(db.system_status.find_one(sort=[("updated_at", -1)]))
    recent_readings = [_serialize_document(item) for item in db.sensor_readings.find().sort("recorded_at", -1).limit(30)]
    recent_events = [_serialize_document(item) for item in db.events.find().sort("created_at", -1).limit(8)]
    recent_commands = [_serialize_document(item) for item in db.commands.find().sort("created_at", -1).limit(8)]
    recent_logs = [_serialize_document(item) for item in db.actuator_logs.find().sort("created_at", -1).limit(8)]

    return {
        "status": latest_status or {
            "mode": "auto",
            "overall_state": "NORMAL",
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



@app.post("/api/readings", tags=["Lecturas"])
def create_reading(payload: SensorReadingCreate):
    db = get_database()
    document = payload.model_dump()
    document["recorded_at"] = document["recorded_at"] or _now()
    result = db.sensor_readings.insert_one(document)

    sensor_type = payload.sensor_type.lower()
    value = payload.value

    key_map = {
        "temperature": "temperature",
        "temperatura": "temperature",
        "humidity": "humidity",
        "humedad": "humidity",
        "humedad_ambiente": "humidity",
        "soil_1": "soil_1",
        "soil_2": "soil_2",
        "humidity_soil_1": "soil_1",
        "humidity_soil_2": "soil_2",
        "humedad_suelo_area1": "soil_1",
        "humedad_suelo_area2": "soil_2",
        "light": "light",
        "luz": "light",
        "gas": "gas",
    }

    status_key = key_map.get(sensor_type)
    if status_key:
        latest = db.system_status.find_one(sort=[("updated_at", -1)])
        temp = value if status_key == "temperature" else (latest.get("temperature", 0.0) if latest else 0.0)
        soil1 = value if status_key == "soil_1" else (latest.get("soil_1", 0.0) if latest else 0.0)
        soil2 = value if status_key == "soil_2" else (latest.get("soil_2", 0.0) if latest else 0.0)
        gas_val = value if status_key == "gas" else (latest.get("gas", 0.0) if latest else 0.0)

        mode = latest.get("mode", "auto") if latest else "auto"
        updates = {status_key: value}

        if mode == "auto":
            if gas_val > 150.0:
                updates["overall_state"] = "EMERGENCIA"
                updates["fan_active"] = True
                updates["buzzer_active"] = True
                if not latest or latest.get("overall_state") != "EMERGENCIA":
                    db.events.insert_one({
                        "event_type": "emergency",
                        "message": f"EMERGENCIA: Gas detectado por encima del límite seguro ({gas_val:.1f}). Alarma y ventilación activadas.",
                        "severity": "critical",
                        "area": "control",
                        "source": "backend_rules",
                        "created_at": _now()
                    })
            elif temp > 30.0:
                updates["overall_state"] = "ADVERTENCIA"
                updates["fan_active"] = True
                if not latest or latest.get("temperature", 0.0) <= 30.0:
                    db.events.insert_one({
                        "event_type": "temp_warning",
                        "message": f"ADVERTENCIA: Temperatura alta detectada ({temp:.1f} °C). Activando ventilación.",
                        "severity": "warning",
                        "area": "control",
                        "source": "backend_rules",
                        "created_at": _now()
                    })
            elif soil1 < 30.0 or soil2 < 30.0:
                updates["overall_state"] = "RIEGO_ACTIVO"
                updates["pump_active"] = True
                dry_area = "Área 1" if soil1 < 30.0 else "Área 2"
                dry_val = soil1 if soil1 < 30.0 else soil2
                if not latest or not latest.get("pump_active", False):
                    db.events.insert_one({
                        "event_type": "soil_warning",
                        "message": f"ADVERTENCIA: Humedad de suelo baja en {dry_area} ({dry_val:.1f}%). Activando bomba.",
                        "severity": "warning",
                        "area": "area_1" if soil1 < 30.0 else "area_2",
                        "source": "backend_rules",
                        "created_at": _now()
                    })
            elif soil1 > 80.0 or soil2 > 80.0:
                updates["overall_state"] = "ADVERTENCIA"
                updates["pump_active"] = False
                sat_area = "Área 1" if soil1 > 80.0 else "Área 2"
                sat_val = soil1 if soil1 > 80.0 else soil2
                if not latest or latest.get("pump_active", False):
                    db.events.insert_one({
                        "event_type": "soil_warning",
                        "message": f"ADVERTENCIA: Suelo saturado en {sat_area} ({sat_val:.1f}%). Riego desactivado.",
                        "severity": "warning",
                        "area": "area_1" if soil1 > 80.0 else "area_2",
                        "source": "backend_rules",
                        "created_at": _now()
                    })
            else:
                updates["overall_state"] = "NORMAL"
                if latest and latest.get("overall_state") in ("ADVERTENCIA", "EMERGENCIA", "RIEGO_ACTIVO"):
                    updates["pump_active"] = False
                    updates["fan_active"] = False
                    updates["buzzer_active"] = False
                    db.events.insert_one({
                        "event_type": "status_restored",
                        "message": "Información: Todos los sensores han retornado a rangos normales.",
                        "severity": "info",
                        "area": "control",
                        "source": "backend_rules",
                        "created_at": _now()
                    })
        else:
            updates["overall_state"] = "MODO_MANUAL"

        update_latest_system_status(updates)

    return {"inserted_id": str(result.inserted_id), "document": document}



@app.post("/api/events", tags=["Eventos"])
def create_event(payload: EventCreate):
    db = get_database()
    document = payload.model_dump()
    document["created_at"] = document["created_at"] or _now()
    result = db.events.insert_one(document)
    return {"inserted_id": str(result.inserted_id), "document": document}


@app.post("/api/commands", tags=["Comandos"])
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


@app.post("/api/system-status", tags=["Estado"])
def upsert_system_status(payload: SystemStatusCreate):
    db = get_database()
    document = payload.model_dump()
    document["updated_at"] = document["updated_at"] or _now()
    result = db.system_status.insert_one(document)
    return {"inserted_id": str(result.inserted_id), "document": document}


@app.post("/api/actuator-logs", tags=["Actuadores"])
def create_actuator_log(payload: ActuatorLogCreate):
    db = get_database()
    document = payload.model_dump()
    document["created_at"] = document["created_at"] or _now()
    result = db.actuator_logs.insert_one(document)
    return {"inserted_id": str(result.inserted_id), "document": document}


@app.post("/api/control/{actuator}", tags=["Control"])
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

    updates = {}
    if actuator == "mode":
        updates["mode"] = state
        if state == "manual":
            updates["overall_state"] = "MODO_MANUAL"
        elif state == "auto":
            updates["overall_state"] = "NORMAL"
    elif actuator == "pump":
        updates["pump_active"] = (state == "on")
        if state == "on":
            updates["overall_state"] = "RIEGO_ACTIVO"
        else:
            latest = db.system_status.find_one(sort=[("updated_at", -1)])
            mode = latest.get("mode", "auto") if latest else "auto"
            updates["overall_state"] = "MODO_MANUAL" if mode == "manual" else "NORMAL"
    elif actuator == "fan":
        updates["fan_active"] = (state == "on")
    elif actuator == "lights":
        updates["lights_active"] = (state == "on")
    elif actuator == "buzzer":
        updates["buzzer_active"] = (state == "active" or state == "on" or state != "mute")

    if updates:
        update_latest_system_status(updates)

    mqtt_result = publish_control_event(f"control/{actuator}", command_document)
    return {
        "command_id": str(command_result.inserted_id),
        "log_id": str(log_result.inserted_id),
        "mqtt": mqtt_result.__dict__,
    }


@app.get("/api/readings/latest", tags=["Lecturas"])
def latest_readings(limit: int = 12):
    db = get_database()
    return [_serialize_document(item) for item in db.sensor_readings.find().sort("recorded_at", -1).limit(limit)]


@app.get("/api/events/latest", tags=["Eventos"])
def latest_events(limit: int = 12):
    db = get_database()
    return [_serialize_document(item) for item in db.events.find().sort("created_at", -1).limit(limit)]


@app.get("/api/commands/latest", tags=["Comandos"])
def latest_commands(limit: int = 12):
    db = get_database()
    return [_serialize_document(item) for item in db.commands.find().sort("created_at", -1).limit(limit)]


@app.get("/api/actuator-logs/latest", tags=["Actuadores"])
def latest_actuator_logs(limit: int = 12):
    db = get_database()
    return [_serialize_document(item) for item in db.actuator_logs.find().sort("created_at", -1).limit(limit)]


@app.get("/api/arm64-results/latest", tags=["ARM64"])
def latest_arm64_results():
    db = get_database()
    modules = ["WEIGHTED_MEAN", "VARIANCE", "ANOMALY_DETECTION", "PREDICTION", "ADVANCED_TREND"]
    results = {}
    for module in modules:
        res = db.arm64_results.find_one({"module": module}, sort=[("created_at", -1)])
        if res:
            results[module] = _serialize_document(res)
    return results


@app.post("/api/arm64-results", tags=["ARM64"])
def create_arm64_result(payload: ARM64ResultCreate):
    db = get_database()
    document = payload.model_dump()
    document["created_at"] = document["created_at"] or _now()
    result = db.arm64_results.insert_one(document)

    db.events.insert_one({
        "event_type": "arm64_analysis",
        "message": f"Nuevo análisis ARM64 registrado para el módulo {payload.module}.",
        "severity": "info",
        "area": "control",
        "source": payload.source,
        "created_at": _now()
    })

    return {"inserted_id": str(result.inserted_id), "document": document}


@app.post("/api/arm64-results/mock", tags=["ARM64"])
def generate_mock_arm64_results():
    db = get_database()
    now = _now()

    mock_data = [
        {
            "module": "WEIGHTED_MEAN",
            "total_values": 30,
            "results": {
                "SUM_X": 920,
                "WEIGHT_SUM": 465,
                "WEIGHTED_MEAN": 31
            },
            "source": "raspi-01",
            "created_at": now
        },
        {
            "module": "VARIANCE",
            "total_values": 30,
            "results": {
                "MEAN": 31,
                "VARIANCE": 18,
                "STD_DEV": 4
            },
            "source": "raspi-01",
            "created_at": now
        },
        {
            "module": "ANOMALY_DETECTION",
            "total_values": 30,
            "results": {
                "MEAN": 29,
                "STD_DEV": 3,
                "ANOMALIES": 4,
                "SYSTEM_RISK": "HIGH"
            },
            "source": "raspi-01",
            "created_at": now
        },
        {
            "module": "PREDICTION",
            "total_values": 30,
            "results": {
                "INITIAL_VALUE": 28,
                "FINAL_VALUE": 34,
                "TOTAL_DIFF": 6,
                "AVG_CHANGE": 0.20,
                "NEXT_VALUE": 34.20
            },
            "source": "raspi-01",
            "created_at": now
        },
        {
            "module": "ADVANCED_TREND",
            "total_values": 30,
            "results": {
                "INCREMENTS": 18,
                "DECREMENTS": 10,
                "MAX_UP_STREAK": 5,
                "MAX_DOWN_STREAK": 3,
                "ACCUM_DIFF": 7,
                "TREND": "UP"
            },
            "source": "raspi-01",
            "created_at": now
        }
    ]

    db.arm64_results.delete_many({"source": "raspi-01"})
    db.arm64_results.insert_many(mock_data)

    db.events.insert_one({
        "event_type": "arm64_analysis",
        "message": "Datos de prueba ARM64 generados exitosamente en la base de datos.",
        "severity": "info",
        "area": "control",
        "source": "api",
        "created_at": now
    })

    return {"status": "ok", "message": "Mock ARM64 results generated"}

