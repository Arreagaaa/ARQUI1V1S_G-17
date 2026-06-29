"""
Router de eventos — Endpoints obligatorios del enunciado.

Endpoints:
  GET  /api/events  — Listar eventos con paginación y filtros
  POST /api/events  — Crear evento
"""

import logging
from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, Query

from ..db import get_database
from ..schemas import EventCreate

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Eventos"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize(doc: dict | None) -> dict | None:
    if not doc:
        return None
    s = dict(doc)
    if isinstance(s.get("_id"), ObjectId):
        s["_id"] = str(s["_id"])
    return s


@router.get("/api/events")
def get_events(
    severity: str | None = Query(default=None, description="Filtrar por severidad: info, warning, critical"),
    event_type: str | None = Query(default=None, description="Filtrar por tipo de evento"),
    limit: int = Query(default=20, ge=1, le=200),
    skip: int = Query(default=0, ge=0),
):
    """
    Obtiene el historial de eventos del sistema con filtros y paginación.

    Incluye alertas automáticas, eventos manuales, cambios de estado,
    y notificaciones del sistema.
    """
    db = get_database()
    query: dict = {}

    if severity:
        query["severity"] = severity
    if event_type:
        query["event_type"] = event_type

    cursor = db.events.find(query).sort("created_at", -1).skip(skip).limit(limit)
    total = db.events.count_documents(query)

    return {
        "data": [_serialize(item) for item in cursor],
        "total": total,
        "limit": limit,
        "skip": skip,
    }


# Mantener endpoint legacy /api/events/latest
@router.get("/api/events/latest")
def legacy_latest_events(limit: int = Query(default=12, ge=1, le=100)):
    """Alias paginado simple (backward compatible)."""
    db = get_database()
    return [_serialize(item) for item in db.events.find().sort("created_at", -1).limit(limit)]


@router.post("/api/events")
def create_event(payload: EventCreate):
    """Crea un nuevo evento en el sistema."""
    db = get_database()
    document = payload.model_dump()
    document["created_at"] = document["created_at"] or _now()
    result = db.events.insert_one(document)

    doc_safe = {k: str(v) if isinstance(v, ObjectId) else v for k, v in document.items()}

    logger.info("Evento registrado: [%s] %s", payload.severity, payload.message[:60])
    return {"inserted_id": str(result.inserted_id), "document": doc_safe}
