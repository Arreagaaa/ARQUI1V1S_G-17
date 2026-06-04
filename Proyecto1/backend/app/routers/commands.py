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
from ..mqtt.publisher import MQTTPublisher

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
    source: str | None = Query(default=None, description="Filtrar por origen"),
    limit: int = Query(default=20, ge=1, le=200),
    skip: int = Query(default=0, ge=0),
):
    """
    Obtiene el historial de comandos enviados al sistema.

    Incluye comandos de control remoto, cambios de modo, y comandos MQTT.
    """
    db = get_database()
    query: dict = {}
    if source:
        query["source"] = {"$regex": f"^{source}$", "$options": "i"}

    cursor = db.commands.find(query).sort("created_at", -1).skip(skip).limit(limit)
    total = db.commands.count_documents(query)

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
    """
    Crea un nuevo comando y lo publica a MQTT (topic control/remoto
    según contrato oficial grupo17/invernadero/control/remoto).

    Importante: este endpoint registra comandos genéricos (no solo de
    actuadores específicos). Para controlar riego/luces/ventilador/
    alarma/modo se recomiendan los endpoints dedicados en /api/control/*.
    """
    db = get_database()
    document = payload.model_dump()
    document["created_at"] = document["created_at"] or _now()
    result = db.commands.insert_one(document)

    # Publicar al topic correcto del contrato MQTT (no a "commands"
    # que no existe en el contrato)
    mqtt_result = MQTTPublisher().publish_control_command(
        command=document["command"],
        target=document["target"],
        state=(document.get("payload") or {}).get("state", "on"),
        area=(document.get("payload") or {}).get("area"),
        source=document.get("source", "web"),
    )

    doc_safe = {k: str(v) if isinstance(v, ObjectId) else v for k, v in document.items()}

    logger.info("Comando creado: %s -> %s", payload.command, payload.target)
    return {
        "inserted_id": str(result.inserted_id),
        "document": doc_safe,
        "mqtt": mqtt_result.__dict__,
    }
