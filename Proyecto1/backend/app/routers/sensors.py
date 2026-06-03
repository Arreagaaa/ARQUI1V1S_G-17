"""
Router de sensores — Endpoints obligatorios del enunciado.

Endpoints:
  GET  /api/sensors/latest   — Últimas lecturas por tipo de sensor
  GET  /api/sensors/history   — Historial con paginación y filtros
  POST /api/readings          — Crear lectura (backward compatible)
"""

import logging
from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, Query

from ..db import get_database
from ..schemas import SensorReadingCreate
from ..services.sensor_service import process_reading

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Sensores"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize(doc: dict | None) -> dict | None:
    if not doc:
        return None
    s = dict(doc)
    if isinstance(s.get("_id"), ObjectId):
        s["_id"] = str(s["_id"])
    return s


@router.get("/api/sensors/latest")
def get_sensors_latest(limit: int = Query(default=12, ge=1, le=100)):
    """
    Obtiene las últimas lecturas de sensores.

    Devuelve las lecturas más recientes ordenadas por fecha descendente.
    Equivalente a GET /api/readings/latest (backward compatible).
    """
    db = get_database()
    readings = db.sensor_readings.find().sort("recorded_at", -1).limit(limit)
    return [_serialize(item) for item in readings]


@router.get("/api/sensors/history")
def get_sensors_history(
    sensor_type: str | None = Query(default=None, description="Filtrar por tipo de sensor"),
    area: str | None = Query(default=None, description="Filtrar por área"),
    limit: int = Query(default=50, ge=1, le=500),
    skip: int = Query(default=0, ge=0),
):
    """
    Obtiene el historial de lecturas de sensores con filtros y paginación.

    Parámetros:
      - sensor_type: temperature, humidity, soil_1, soil_2, light, gas
      - area: area_1, area_2, control
      - limit: máximo de resultados (1-500)
      - skip: offset para paginación
    """
    db = get_database()
    query: dict = {}

    if sensor_type:
        query["sensor_type"] = {"$regex": sensor_type, "$options": "i"}
    if area:
        query["area"] = area

    cursor = db.sensor_readings.find(query).sort("recorded_at", -1).skip(skip).limit(limit)
    total = db.sensor_readings.count_documents(query)

    return {
        "data": [_serialize(item) for item in cursor],
        "total": total,
        "limit": limit,
        "skip": skip,
    }


# Mantener endpoint legacy /api/readings/latest para backward compatibility
@router.get("/api/readings/latest")
def legacy_latest_readings(limit: int = Query(default=12, ge=1, le=100)):
    """Alias de /api/sensors/latest (backward compatible)."""
    return get_sensors_latest(limit)


@router.post("/api/readings")
def create_reading(payload: SensorReadingCreate):
    """
    Crea una nueva lectura de sensor.

    Al registrar la lectura:
    1. Se inserta en la colección sensor_readings
    2. Se procesan las reglas de automatización
    3. Se actualiza el estado global del sistema
    """
    db = get_database()
    document = payload.model_dump()
    document["recorded_at"] = document["recorded_at"] or _now()
    result = db.sensor_readings.insert_one(document)

    # Procesar reglas de automatización
    process_reading(document)

    doc_safe = {k: str(v) if isinstance(v, ObjectId) else v for k, v in document.items()}

    logger.info("Lectura registrada: %s = %.1f (%s)", payload.sensor_type, payload.value, payload.area)
    return {"inserted_id": str(result.inserted_id), "document": doc_safe}
