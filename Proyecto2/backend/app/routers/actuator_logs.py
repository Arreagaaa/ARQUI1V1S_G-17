import logging
from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, Query

from ..db import get_database
from ..schemas import ActuatorLogCreate

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Actuadores"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize(doc: dict | None) -> dict | None:
    if not doc:
        return None
    s = dict(doc)
    if isinstance(s.get("_id"), ObjectId):
        s["_id"] = str(s["_id"])
    return s


@router.get("/api/actuator-logs")
def get_actuator_logs(
    actuator: str | None = Query(default=None, description="Filtrar por actuador"),
    limit: int = Query(default=20, ge=1, le=200),
    skip: int = Query(default=0, ge=0),
):
    db = get_database()
    query = {}
    if actuator:
        query["actuator"] = actuator
    cursor = db.actuator_logs.find(query).sort("created_at", -1).skip(skip).limit(limit)
    total = db.actuator_logs.count_documents(query)
    return {
        "data": [_serialize(item) for item in cursor],
        "total": total,
        "limit": limit,
        "skip": skip,
    }


@router.get("/api/actuator-logs/latest")
def legacy_latest_actuator_logs(limit: int = Query(default=12, ge=1, le=100)):
    db = get_database()
    return [_serialize(item) for item in db.actuator_logs.find().sort("created_at", -1).limit(limit)]


@router.post("/api/actuator-logs")
def create_actuator_log(payload: ActuatorLogCreate):
    db = get_database()
    document = payload.model_dump()
    document["created_at"] = document["created_at"] or _now()
    result = db.actuator_logs.insert_one(document)
    doc_safe = {k: str(v) if isinstance(v, ObjectId) else v for k, v in document.items()}
    logger.info("Log de actuador registrado: %s -> %s", payload.actuator, payload.action)
    return {"inserted_id": str(result.inserted_id), "document": doc_safe}
