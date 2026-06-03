"""
Router de comandos — Endpoints obligatorios del enunciado.

Endpoints:
  GET  /api/commands  — Listar comandos con paginación
  POST /api/commands  — Crear comando
"""

import logging
from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, Query

from ..db import get_database
from ..schemas import CommandCreate
from ..mqtt_service import publish_control_event

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Comandos"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize(doc: dict | None) -> dict | None:
    if not doc:
        return None
    s = dict(doc)
    if isinstance(s.get("_id"), ObjectId):
        s["_id"] = str(s["_id"])
    return s


@router.get("/api/commands")
def get_commands(
    limit: int = Query(default=20, ge=1, le=200),
    skip: int = Query(default=0, ge=0),
):
    """
    Obtiene el historial de comandos enviados al sistema.

    Incluye comandos de control remoto, cambios de modo, y comandos MQTT.
    """
    db = get_database()
    cursor = db.commands.find().sort("created_at", -1).skip(skip).limit(limit)
    total = db.commands.count_documents({})

    return {
        "data": [_serialize(item) for item in cursor],
        "total": total,
        "limit": limit,
        "skip": skip,
    }


# Mantener endpoint legacy
@router.get("/api/commands/latest")
def legacy_latest_commands(limit: int = Query(default=12, ge=1, le=100)):
    """Alias simple (backward compatible)."""
    db = get_database()
    return [_serialize(item) for item in db.commands.find().sort("created_at", -1).limit(limit)]


@router.post("/api/commands")
def create_command(payload: CommandCreate):
    """Crea un nuevo comando."""
    db = get_database()
    document = payload.model_dump()
    document["created_at"] = document["created_at"] or _now()
    result = db.commands.insert_one(document)
    mqtt_result = publish_control_event("commands", document)

    logger.info("Comando creado: %s -> %s", payload.command, payload.target)
    return {
        "inserted_id": str(result.inserted_id),
        "document": document,
        "mqtt": mqtt_result.__dict__,
    }
