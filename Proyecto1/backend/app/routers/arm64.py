"""
Router de ARM64 — Endpoints de procesamiento del coprocesador ARM64.

Endpoints requeridos por el enunciado:
  GET  /api/arm64/results — Obtener resultados de los análisis ARM64

Endpoints legacy (compatibilidad):
  GET  /api/arm64-results/latest
  POST /api/arm64-results
  POST /api/arm64-results/mock
"""

import logging
from datetime import datetime, timezone
from bson import ObjectId
from fastapi import APIRouter

from ..db import get_database
from ..schemas import ARM64ResultCreate

logger = logging.getLogger(__name__)
router = APIRouter(tags=["ARM64"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize(doc: dict | None) -> dict | None:
    if not doc:
        return None
    s = dict(doc)
    if isinstance(s.get("_id"), ObjectId):
        s["_id"] = str(s["_id"])
    return s


@router.get("/api/arm64/results")
def get_arm64_results():
    """
    Obtiene los últimos resultados de análisis procesados en ensamblador ARM64.
    
    Retorna el último registro para cada uno de los 5 módulos:
      - WEIGHTED_MEAN
      - VARIANCE
      - ANOMALY_DETECTION
      - PREDICTION
      - ADVANCED_TREND
    """
    db = get_database()
    modules = ["WEIGHTED_MEAN", "VARIANCE", "ANOMALY_DETECTION", "PREDICTION", "ADVANCED_TREND"]
    results = {}
    for module in modules:
        res = db.arm64_results.find_one({"module": module}, sort=[("created_at", -1)])
        if res:
            results[module] = _serialize(res)
    return results


# Alias legacy de GET /api/arm64/results para compatibilidad con la UI existente
@router.get("/api/arm64-results/latest")
def legacy_latest_arm64_results():
    """Alias para /api/arm64/results (backward compatible)."""
    return get_arm64_results()


@router.post("/api/arm64-results")
def create_arm64_result(payload: ARM64ResultCreate):
    """
    Registra un nuevo resultado de cálculo proveniente de la Raspberry Pi (ARM64).
    Al registrar el resultado se genera un evento informativo en el historial.
    """
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

    doc_safe = {k: str(v) if isinstance(v, ObjectId) else v for k, v in document.items()}

    logger.info("Resultado ARM64 registrado: %s por %s", payload.module, payload.source)
    return {"inserted_id": str(result.inserted_id), "document": doc_safe}


@router.post("/api/arm64-results/mock")
def generate_mock_arm64_results(dev: bool = False):
    """
    [SOLO DESARROLLO] Genera datos mock para simular el coprocesador ARM64.
    No usar en produccion — los resultados deben venir de ejecucion real ARM64.

    Query parameter ?dev=true requerido para confirmar.
    """
    if not dev:
        return {"status": "error",
                "message": "Endpoint solo para desarrollo. Usa ?dev=true para confirmar. "
                           "Los resultados ARM64 deben generarse ejecutando los modulos .s"}
    db = get_database()
    now = _now()

    mock_data = [
        {
            "module": "WEIGHTED_MEAN",
            "total_values": 30,
            "results": {
                "SUM_X": 892,
                "WEIGHT_SUM": 465,
                "WEIGHTED_MEAN": 30
            },
            "source": "raspi-01",
            "created_at": now
        },
        {
            "module": "VARIANCE",
            "total_values": 30,
            "results": {
                "MEAN": 29,
                "VARIANCE": 10,
                "STD_DEV": 3
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
                "ANOMALIES": 2,
                "SYSTEM_RISK": "MEDIUM"
            },
            "source": "raspi-01",
            "created_at": now
        },
        {
            "module": "PREDICTION",
            "total_values": 30,
            "results": {
                "INITIAL_VALUE": 22,
                "FINAL_VALUE": 30,
                "TOTAL_DIFF": 8,
                "AVG_CHANGE": 0.27,
                "NEXT_VALUE": 30.27
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
                "MAX_UP_STREAK": 12,
                "MAX_DOWN_STREAK": 6,
                "ACCUM_DIFF": 8,
                "TREND": "UP"
            },
            "source": "raspi-01",
            "created_at": now
        }
    ]

    # Eliminar previos del mismo origen e insertar los nuevos
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

    logger.info("Datos de prueba ARM64 generados exitosamente.")
    return {"status": "ok", "message": "Mock ARM64 results generated"}


COLUMN_LABELS = {
    0: "ID", 1: "TEMP", 2: "HUM_AIRE", 3: "HUM_SUELO_1",
    4: "HUM_SUELO_2", 5: "LUZ", 6: "GAS", 7: "RIEGO_1", 8: "RIEGO_2",
}

DEFAULT_COLUMNS = {1: 1, 2: 1, 3: 1, 4: 4, 5: 1}


@router.get("/api/arm64/column-config")
def get_arm64_column_config():
    """Obtiene la configuración de columnas para cada módulo ARM64."""
    db = get_database()
    doc = db.arm64_column_config.find_one(sort=[("updated_at", -1)])
    if doc:
        cols = doc.get("columns", {})
        return {
            "columns": {int(k): v for k, v in cols.items()},
            "labels": {int(k): COLUMN_LABELS.get(int(v), f"col{v}") for k, v in cols.items()},
        }
    return {
        "columns": DEFAULT_COLUMNS,
        "labels": {k: COLUMN_LABELS.get(v, f"col{v}") for k, v in DEFAULT_COLUMNS.items()},
    }


@router.post("/api/arm64/column-config")
def set_arm64_column_config(payload: dict):
    """Guarda la configuración de columnas para cada módulo ARM64."""
    db = get_database()
    columns = payload.get("columns", {})
    doc = {
        "columns": {str(k): int(v) for k, v in columns.items()},
        "updated_at": _now(),
    }
    db.arm64_column_config.insert_one(doc)
    return {"status": "ok", "columns": columns, "labels": {int(k): COLUMN_LABELS.get(int(v), f"col{v}") for k, v in columns.items()}}
