"""
Router de estado — Monitoreo del estado global y del panel de control.

Endpoints:
  GET  /api/status        — Estado actual consolidado de los sensores y actuadores
  GET  /api/dashboard     — Resumen consolidado para la interfaz de usuario
  POST /api/system-status — Registrar/actualizar estado (sincronización externa)
"""

import logging
from datetime import datetime, timezone
from bson import ObjectId
from fastapi import APIRouter

from ..db import get_database
from ..schemas import SystemStatusCreate

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Estado"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize(doc: dict | None) -> dict | None:
    if not doc:
        return None
    s = dict(doc)
    if isinstance(s.get("_id"), ObjectId):
        s["_id"] = str(s["_id"])
    return s


@router.get("/api/status")
def get_system_status():
    """
    Obtiene el estado global más reciente del sistema.
    
    Incluye el modo actual (auto/manual), el estado de alerta general,
    los últimos valores medidos de cada variable y los estados de los actuadores.
    """
    db = get_database()
    latest = db.system_status.find_one(sort=[("updated_at", -1)])
    if latest:
        return _serialize(latest)
    
    # Valores de contingencia/iniciales si la base de datos está vacía
    return {
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
        "source": "system",
        "updated_at": _now()
    }


@router.get("/api/dashboard")
def get_dashboard_summary():
    """
    Retorna toda la información requerida por el Dashboard de un solo llamado.
    
    Incluye:
      - Estado global actual
      - Últimas 30 lecturas de sensores
      - Últimos 8 eventos/alertas
      - Últimos 8 comandos enviados
      - Últimos 8 logs de actuación de hardware
    """
    db = get_database()
    
    # 1. Estado global actual
    latest_status = db.system_status.find_one(sort=[("updated_at", -1)])
    serialized_status = _serialize(latest_status) or {
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
        "updated_at": _now(),
    }
    
    # 2. Colecciones recientes
    recent_readings = [_serialize(item) for item in db.sensor_readings.find().sort("recorded_at", -1).limit(30)]
    recent_events = [_serialize(item) for item in db.events.find().sort("created_at", -1).limit(8)]
    recent_commands = [_serialize(item) for item in db.commands.find().sort("created_at", -1).limit(8)]
    recent_logs = [_serialize(item) for item in db.actuator_logs.find().sort("created_at", -1).limit(8)]

    return {
        "status": serialized_status,
        "recent_readings": recent_readings,
        "recent_events": recent_events,
        "recent_commands": recent_commands,
        "recent_logs": recent_logs,
    }


@router.post("/api/system-status")
def upsert_system_status(payload: SystemStatusCreate):
    """
    Inserta un nuevo registro de estado global.
    Utilizado usualmente por la Raspberry Pi para reportar su estado real sincronizado.
    """
    db = get_database()
    document = payload.model_dump()
    document["updated_at"] = document["updated_at"] or _now()
    result = db.system_status.insert_one(document)
    doc_safe = {k: str(v) if isinstance(v, ObjectId) else v for k, v in document.items()}

    logger.info("Estado del sistema actualizado por %s", payload.source)
    return {"inserted_id": str(result.inserted_id), "document": doc_safe}


@router.post("/api/seed")
def trigger_database_seed(clear: bool = False):
    """
    Inicializa/Siembra la base de datos con datos mock coherentes de prueba.

    - clear=false (default): solo siembra las colecciones que estén VACÍAS.
      No destruye comandos, eventos o logs generados por el usuario vía MQTTX.
    - clear=true: VACÍA las 6 colecciones y siembra desde cero. Usar solo
      si querés reiniciar la BD completa (botón rojo del dashboard).

    El frontend debe pedir confirmación al usuario cuando clear=true.
    """
    from ..seed import seed_database
    res = seed_database(clear_existing=clear)
    if clear:
        msg = "Base de datos VACIADA y re-sembrada con datos de prueba."
    else:
        msg = "Base de datos sembrada (modo seguro: no se borraron datos existentes)."
    return {"status": "ok", "cleared": clear, "message": msg, "details": res}

