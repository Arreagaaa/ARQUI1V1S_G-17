"""
SensorService — Lógica de negocio para lectura de sensores.

Incluye:
- Procesamiento de lecturas con reglas de automatización
- Actualización del estado global basado en umbrales
- Generación automática de eventos ante condiciones anómalas
"""

import logging
from datetime import datetime, timezone

from ..db import get_database

logger = logging.getLogger(__name__)


def _now() -> datetime:
    return datetime.now(timezone.utc)


# Mapeo de tipos de sensor a claves del estado global
SENSOR_KEY_MAP = {
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


def update_system_status(updates: dict) -> dict:
    """
    Actualiza el estado global del sistema insertando un nuevo documento.

    Si ya existe un estado previo, lo toma como base y aplica las
    actualizaciones. Si no existe, crea uno con valores por defecto.
    """
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


def process_reading(document: dict) -> dict:
    """
    Procesa una lectura de sensor y aplica reglas de automatización.

    Reglas de automatización (modo auto):
    1. Gas > 150 ppm → EMERGENCIA (activa ventilador + alarma)
    2. Temperatura > 30 °C → ADVERTENCIA (activa ventilador)
    3. Suelo < 30% → RIEGO_ACTIVO (activa bomba)
    4. Suelo > 80% → ADVERTENCIA (desactiva bomba)
    5. Todo normal → NORMAL (desactiva todo)
    """
    db = get_database()
    sensor_type = document.get("sensor_type", "").lower()
    value = document.get("value", 0.0)

    status_key = SENSOR_KEY_MAP.get(sensor_type)
    if not status_key:
        return document

    latest = db.system_status.find_one(sort=[("updated_at", -1)])
    temp = value if status_key == "temperature" else (latest.get("temperature", 0.0) if latest else 0.0)
    soil1 = value if status_key == "soil_1" else (latest.get("soil_1", 0.0) if latest else 0.0)
    soil2 = value if status_key == "soil_2" else (latest.get("soil_2", 0.0) if latest else 0.0)
    gas_val = value if status_key == "gas" else (latest.get("gas", 0.0) if latest else 0.0)

    mode = latest.get("mode", "auto") if latest else "auto"
    updates = {status_key: value}

    if mode == "auto":
        _apply_automation_rules(db, updates, latest, temp, soil1, soil2, gas_val)
    else:
        updates["overall_state"] = "MODO_MANUAL"

    update_system_status(updates)
    return document


def _apply_automation_rules(db, updates: dict, latest: dict | None,
                            temp: float, soil1: float, soil2: float,
                            gas_val: float) -> None:
    """Aplica las reglas de automatización basadas en umbrales de sensores."""

    # Regla 1: EMERGENCIA por gas
    if gas_val > 150.0:
        updates["overall_state"] = "EMERGENCIA"
        updates["fan_active"] = True
        updates["buzzer_active"] = True
        if not latest or latest.get("overall_state") != "EMERGENCIA":
            db.events.insert_one({
                "event_type": "emergency",
                "message": f"EMERGENCIA: Gas detectado por encima del límite seguro ({gas_val:.1f} ppm). Alarma y ventilación activadas.",
                "severity": "critical",
                "area": "control",
                "source": "backend_rules",
                "created_at": _now(),
            })
            logger.warning("EMERGENCIA: Gas = %.1f ppm", gas_val)

    # Regla 2: ADVERTENCIA por temperatura alta
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
                "created_at": _now(),
            })
            logger.warning("Temperatura alta: %.1f °C", temp)

    # Regla 3: RIEGO por suelo seco
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
                "created_at": _now(),
            })

    # Regla 4: Suelo saturado
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
                "created_at": _now(),
            })

    # Regla 5: Todo normal
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
                "created_at": _now(),
            })
