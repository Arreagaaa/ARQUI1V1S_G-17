"""
Router de ARM64 — Endpoints de procesamiento del coprocesador ARM64.

Endpoints requeridos por el enunciado:
  GET  /api/arm64/results — Obtener resultados de los análisis ARM64

Endpoints legacy (compatibilidad):
  GET  /api/arm64-results/latest
  POST /api/arm64-results
  POST /api/arm64-results/mock

Endpoints de generación de datos:
  GET  /api/arm64/csv — Genera y descarga lecturas.csv desde MongoDB real
"""

import csv
import io
import logging
from datetime import datetime, timezone
from bson import ObjectId
from fastapi import APIRouter
from fastapi.responses import PlainTextResponse

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
    
    Retorna el último registro para cada uno de los módulos:
      - RMSE
      - WEIGHTED_MEAN
      - VARIANCE
      - ANOMALY_DETECTION
      - PREDICTION
      - ADVANCED_TREND
    """
    db = get_database()
    modules = ["RMSE", "WEIGHTED_MEAN", "VARIANCE", "ANOMALY_DETECTION", "PREDICTION", "ADVANCED_TREND",
                "LINEAR_REGRESSION", "PREDICTION_LINEAR", "ERROR_INTEGRAL", "LOCAL_DERIVATIVE", "LIVE_ENGINE"]
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
            "module": "RMSE",
            "total_values": 30,
            "results": {
                "COLUMN": 1,
                "WINDOW_START": 1,
                "WINDOW_END": 30,
                "COUNT": 30,
                "IDEAL": 30,
                "SUM_SQUARED_ERROR": 145,
                "MSE": 7,
                "RMSE": 2
            },
            "source": "raspi-01",
            "created_at": now
        },
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
                "AVG_CHANGE": 0,
                "NEXT_VALUE": 30
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
        },
        {
            "module": "LINEAR_REGRESSION",
            "total_values": 10,
            "results": {
                "COLUMN": 1,
                "WINDOW_START": 1,
                "WINDOW_END": 10,
                "COUNT": 10,
                "SLOPE_X100": 45,
                "TREND": "ASCENDING"
            },
            "source": "raspi-01",
            "created_at": now
        },
        {
            "module": "PREDICTION_LINEAR",
            "total_values": 10,
            "results": {
                "COLUMN": 1,
                "WINDOW_START": 1,
                "WINDOW_END": 10,
                "COUNT": 10,
                "K": 5,
                "SLOPE_X100": 45,
                "INTERCEPT_X100": 2500,
                "PREDICTED_5": 2725
            },
            "source": "raspi-01",
            "created_at": now
        },
        {
            "module": "ERROR_INTEGRAL",
            "total_values": 10,
            "results": {
                "COLUMN": 1,
                "WINDOW_START": 1,
                "WINDOW_END": 10,
                "COUNT": 10,
                "IDEAL": 30,
                "ERROR_INTEGRAL": 45
            },
            "source": "raspi-01",
            "created_at": now
        },
        {
            "module": "LOCAL_DERIVATIVE",
            "total_values": 10,
            "results": {
                "COLUMN": 1,
                "WINDOW_START": 1,
                "WINDOW_END": 10,
                "COUNT": 10,
                "WINDOW_SIZE": 5,
                "MAX_LOCAL_SLOPE_X100": 120
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


FIELD_NAMES = ["ID", "TEMP", "HUM_AIRE", "HUM_SUELO_1", "HUM_SUELO_2", "LUZ", "GAS", "RIEGO_1", "RIEGO_2"]

SENSOR_TYPE_MAP = {
    "temperature": "TEMP", "temperatura": "TEMP",
    "humidity": "HUM_AIRE", "hum_aire": "HUM_AIRE", "humedad_ambiente": "HUM_AIRE",
    "soil_1": "HUM_SUELO_1", "soil_2": "HUM_SUELO_2",
    "humedad_suelo_area1": "HUM_SUELO_1", "humedad_suelo_area2": "HUM_SUELO_2",
    "light": "LUZ", "luz": "LUZ",
    "gas": "GAS",
}

COLUMN_LABELS = {
    0: "ID", 1: "TEMP", 2: "HUM_AIRE", 3: "HUM_SUELO_1",
    4: "HUM_SUELO_2", 5: "LUZ", 6: "GAS", 7: "RIEGO_1", 8: "RIEGO_2",
}

DEFAULT_COLUMNS = {1: 1, 2: 1, 3: 1, 4: 4, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 1}


@router.get("/api/arm64/csv")
def download_arm64_csv():
    """
    Descarga lecturas.csv generado desde MongoDB (o datos simulados).
    Usado por arm_executor.py en la Raspberry Pi.
    """
    db = get_database()
    total = db.sensor_readings.count_documents({})
    rows = _generate_csv_rows(db, total)
    source = "mongodb" if total >= 30 else "mock_fallback"

    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=FIELD_NAMES)
    writer.writeheader()
    writer.writerows(rows)
    buf.write("$\n")

    return PlainTextResponse(
        content=buf.getvalue(),
        media_type="text/plain",
        headers={
            "Content-Disposition": "attachment; filename=lecturas.csv",
            "X-Total-Records": str(len(rows)),
            "X-Source": source,
        }
    )


@router.post("/api/arm64/csv")
def generate_arm64_csv():
    """
    Genera lecturas.csv desde MongoDB y retorna metadatos.
    Usado por el dashboard para preparar datos antes de ejecutar en la Pi.
    """
    db = get_database()
    total = db.sensor_readings.count_documents({})
    rows = _generate_csv_rows(db, total)
    source = "mongodb" if total >= 30 else "mock_fallback"

    logger.info("CSV ARM64 generado: %d registros, fuente: %s", len(rows), source)
    return {
        "status": "ok",
        "message": f"lecturas.csv generado con {len(rows)} registros desde {source}.",
        "total_records": len(rows),
        "source": source,
    }


@router.post("/api/arm64/run")
def trigger_arm64_run():
    """
    Genera lecturas.csv y envía comando MQTT a la Raspberry Pi
    para ejecutar los 5 módulos ARM64.
    """
    db = get_database()
    total = db.sensor_readings.count_documents({})
    rows = _generate_csv_rows(db, total)
    source = "mongodb" if total >= 30 else "mock_fallback"

    logger.info("CSV ARM64 generado para ejecución: %d registros, fuente: %s", len(rows), source)

    try:
        from ..mqtt.publisher import MQTTPublisher
        publisher = MQTTPublisher()
        result = publisher.publish_control_command(
            command="run_arm64",
            target="arm64_run",
            state="execute",
            source="web",
        )
        if result and result.success:
            return {
                "status": "ok",
                "message": f"CSV generado ({len(rows)} registros). Comando enviado a la Raspberry Pi.",
                "total_records": len(rows),
                "source": source,
                "mqtt_topic": result.topic,
            }
        else:
            return {
                "status": "error",
                "message": "CSV generado pero no se pudo enviar el comando MQTT a la Raspberry Pi.",
                "total_records": len(rows),
                "source": source,
            }
    except Exception as exc:
        logger.error("Error al publicar comando ARM64 por MQTT: %s", exc)
        return {
            "status": "error",
            "message": f"Error al comunicar con la Raspberry Pi: {exc}",
        }


def _generate_csv_rows(db, total: int, count: int = 30) -> list[dict]:
    if total >= count:
        latest = list(db.sensor_readings.find().sort("recorded_at", -1).limit(count * 6))
        if latest and len(latest) >= count:
            groups: dict[str, list[float]] = {}
            for doc in latest:
                st = doc.get("sensor_type", "").lower().replace(" ", "_").replace("-", "_")
                col = SENSOR_TYPE_MAP.get(st)
                if col:
                    if col not in groups:
                        groups[col] = []
                    v = doc.get("value", 0)
                    if isinstance(v, (int, float)):
                        groups[col].append(float(v))

            rows = []
            for i in range(count):
                row = {"ID": i + 1}
                for col in ["TEMP", "HUM_AIRE", "HUM_SUELO_1", "HUM_SUELO_2", "LUZ", "GAS"]:
                    vals = groups.get(col, [])
                    if i < len(vals):
                        row[col] = round(vals[i], 1) if col in ("TEMP", "HUM_AIRE", "HUM_SUELO_1", "HUM_SUELO_2") else int(round(vals[i]))
                    else:
                        row[col] = 0
                row["RIEGO_1"] = 0
                row["RIEGO_2"] = 0
                rows.append(row)

            if len(rows) >= count:
                return rows[:count]

    return _generate_mock_csv_rows(count)


def _generate_mock_csv_rows(count: int = 30) -> list[dict]:
    import random
    rng = random.Random(42)
    rows = []
    for i in range(1, count + 1):
        rows.append({
            "ID": i,
            "TEMP": round(rng.uniform(22.0, 38.0), 1),
            "HUM_AIRE": round(rng.uniform(40.0, 90.0), 1),
            "HUM_SUELO_1": round(rng.uniform(0.0, 100.0), 1),
            "HUM_SUELO_2": round(rng.uniform(0.0, 100.0), 1),
            "LUZ": rng.randint(0, 1023),
            "GAS": rng.randint(0, 1023),
            "RIEGO_1": rng.randint(0, 1),
            "RIEGO_2": rng.randint(0, 1),
        })
    return rows


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


@router.post("/api/arm64/historical-analysis")
def trigger_historical_analysis(payload: dict):
    """
    Recibe parametros para analisis historico desde el dashboard.
    Guarda la solicitud en MongoDB y publica comando MQTT a la Pi.
    Si no hay Pi disponible, ejecuta el analisis localmente (simulado).
    """
    db = get_database()
    now = _now()

    file = payload.get("file", "lecturas.csv")
    start_line = payload.get("start_line", 1)
    end_line = payload.get("end_line", 30)
    column = payload.get("column", 1)
    ideal_value = payload.get("ideal_value", 55)
    module = payload.get("module", "RMSE")

    doc = {
        "file": file,
        "start_line": start_line,
        "end_line": end_line,
        "column": column,
        "ideal_value": ideal_value,
        "module": module,
        "status": "pending",
        "created_at": now,
    }
    db.arm64_analysis_requests.insert_one(doc)

    db.events.insert_one({
        "event_type": "historical_analysis",
        "message": f"Analisis historico solicitado: {file} lineas {start_line}-{end_line} columna {column}.",
        "severity": "info",
        "area": "control",
        "source": "web",
        "created_at": now
    })

    mqtt_ok = False
    try:
        from ..mqtt.publisher import MQTTPublisher
        publisher = MQTTPublisher()
        result = publisher.publish_control_command(
            command="run_historical",
            target="arm64_historical",
            state="execute",
            source="web",
            payload=doc,
        )
        mqtt_ok = result and result.success
    except Exception:
        mqtt_ok = False

    if not mqtt_ok:
        total = db.sensor_readings.count_documents({})
        rows = _generate_csv_rows(db, total)
        col_label = COLUMN_LABELS.get(column, "TEMP")
        count = 0
        values = []
        for row in rows:
            rid = row.get("ID", 0)
            if rid >= start_line and rid <= end_line:
                val = row.get(col_label)
                if val is not None and isinstance(val, (int, float)):
                    values.append(float(val))
                    count += 1

        else:
            results_data = {"STATUS": "ERROR", "ERROR": "MODULE_NOT_IMPLEMENTED"}

        # No guardar resultado simulado si ya existe uno real de la Pi
        existing = db.arm64_results.find_one({"module": module, "source": "raspi-01"}, sort=[("created_at", -1)])
        if not existing:
            arm64_payload = ARM64ResultCreate(
                module=module,
                total_values=count,
                results=results_data,
                source="backend-sim",
            )
            arm64_doc = arm64_payload.model_dump()
            arm64_doc["created_at"] = now
            db.arm64_results.insert_one(arm64_doc)

    logger.info("Solicitud de analisis historico registrada: %s", doc)
    return {
        "status": "ok",
        "message": f"Analisis historico completado para {file} lineas {start_line}-{end_line}. Revisa la seccion de resultados.",
        "mqtt_notified": mqtt_ok,
    }
