"""
Script de inicialización y siembra de base de datos (Seeder).

Pobla MongoDB con datos de prueba realistas para las 6 colecciones principales:
1. sensor_readings: Lecturas históricas de temperatura, humedad, suelo, luz y gas.
2. events: Registro histórico de alertas, restauraciones de estado y análisis.
3. commands: Comandos remotos e internos enviados a los actuadores.
4. system_status: Historial de estados del sistema para graficar y el estado más reciente.
5. actuator_logs: Historial de actuación del hardware.
6. arm64_results: Resultados simulados de cálculos ARM64 (Weighted Mean, Variance, etc.).

IMPORTANTE: Por defecto `clear_existing=False` para NO destruir comandos,
eventos o logs de actuadores generados por el usuario vía MQTTX.
Solo sembrar al inicio (cuando la BD está vacía). Para reiniciar la BD completa,
usar `?clear=true` en el endpoint o llamar a seed_database(clear_existing=True).
"""

import logging
import random
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List

from .db import get_database
from .mqtt.mock_provider import MQTTMockProvider

logger = logging.getLogger(__name__)


def seed_database(clear_existing: bool = False) -> Dict[str, Any]:
    """
    Pobla la base de datos con un set de datos mock coherentes.

    Args:
        clear_existing: Si es True, vacía TODAS las colecciones antes de
            insertar. Usar con cuidado: borra también los comandos y logs
            que el usuario haya enviado vía MQTTX. Default: False
            (solo siembra si la colección está vacía).

    Returns:
        Un resumen de los documentos insertados por colección.
    """
    db = get_database()
    now = datetime.now(timezone.utc)

    if clear_existing:
        logger.warning("ATENCIÓN: Limpiando TODAS las colecciones (incluyendo comandos del usuario)")
        db.sensor_readings.delete_many({})
        db.events.delete_many({})
        db.commands.delete_many({})
        db.system_status.delete_many({})
        db.actuator_logs.delete_many({})
        db.arm64_results.delete_many({})

    mock_provider = MQTTMockProvider(seed=42)
    results = {}

    def _seed_if_empty(coll_name: str, docs: List[dict]) -> int:
        """Inserta docs solo si la colección está vacía. Devuelve n insertados."""
        if not clear_existing and db[coll_name].count_documents({}) > 0:
            logger.info("Colección '%s' ya tiene datos: omitiendo siembra", coll_name)
            return 0
        if not docs:
            return 0
        db[coll_name].insert_many(docs)
        return len(docs)
    
    # 1. Generar lecturas históricas (30 sets de 6 sensores = 180 lecturas)
    logger.info("Generando lecturas históricas de sensores...")
    historical_raw = mock_provider.generate_historical_readings(count=30)
    
    # Adaptar timestamps a datetime objects para MongoDB
    sensor_readings = []
    for raw in historical_raw:
        dt = datetime.fromisoformat(raw["timestamp"])
        sensor_readings.append({
            "sensor_type": raw["sensor_type"],
            "value": raw["value"],
            "unit": raw["unit"],
            "area": raw["area"],
            "status": raw["status"],
            "source": raw["source"],
            "recorded_at": dt
        })

    results["sensor_readings"] = _seed_if_empty("sensor_readings", sensor_readings)
    
    # 2. Generar estados del sistema coherentes a lo largo del tiempo
    logger.info("Generando estados de sistema históricos...")
    system_status_list = []
    base_time = now - timedelta(minutes=30 * 5)
    
    # Vamos a simular un avance temporal
    for i in range(30):
        timestamp = base_time + timedelta(minutes=i * 5)
        # Extraer lecturas correspondientes a este bloque temporal
        temp = 22.0 + (i * 0.3) % 15.0
        hum = 60.0 - (i * 0.5) % 25.0
        soil1 = 45.0 - (i * 0.8) % 30.0
        soil2 = 50.0 - (i * 0.6) % 25.0
        light = 40.0 + (i * 1.5) % 55.0
        gas = 60.0 + (i * 3.0) % 110.0
        
        # Reglas simples para inferir estado
        pump = soil1 < 65.0 or soil2 < 65.0
        fan = temp > 30.0 or gas > 90.0
        lights = light < 30.0
        buzzer = gas > 90.0
        
        if gas > 90.0:
            state = "EMERGENCIA"
        elif temp > 30.0 or soil1 < 65.0 or soil2 < 65.0:
            state = "ADVERTENCIA" if temp > 30.0 else "RIEGO_ACTIVO"
        else:
            state = "NORMAL"
            
        irr_state = "RIEGO_AREA_1" if pump else "RIEGO_OFF"
        vent_state = "VENTILACION_EMERGENCIA" if gas > 90.0 else ("VENTILACION_ON" if fan else "VENTILACION_OFF")
        gas_state = "GAS_EMERGENCIA" if gas > 90.0 else ("GAS_ADVERTENCIA" if gas > 65.0 else "GAS_NORMAL")

        system_status_list.append({
            "mode": "auto",
            "overall_state": state,
            "irrigation_state": irr_state,
            "ventilation_state": vent_state,
            "gas_state": gas_state,
            "temperature": round(temp, 1),
            "humidity": round(hum, 1),
            "soil_1": round(soil1, 1),
            "soil_2": round(soil2, 1),
            "light": round(light, 1),
            "gas": round(gas, 1),
            "pump_active": pump,
            "fan_active": fan,
            "lights_active": lights,
            "buzzer_active": buzzer,
            "source": "raspi-01",
            "updated_at": timestamp
        })

    results["system_status"] = _seed_if_empty("system_status", system_status_list)
    
    # 3. Generar eventos simulados coherentes
    logger.info("Generando eventos y logs históricos...")
    events = [
        {
            "event_type": "status_restored",
            "message": "Información: Todos los sensores han retornado a rangos normales.",
            "severity": "info",
            "area": "control",
            "source": "backend_rules",
            "created_at": now - timedelta(minutes=140)
        },
        {
            "event_type": "soil_warning",
            "message": "ADVERTENCIA: Humedad de suelo baja en Área 1 (28.4%). Activando bomba.",
            "severity": "warning",
            "area": "area_1",
            "source": "backend_rules",
            "created_at": now - timedelta(minutes=110)
        },
        {
            "event_type": "temp_warning",
            "message": "ADVERTENCIA: Temperatura alta detectada (31.2 °C). Activando ventilación.",
            "severity": "warning",
            "area": "control",
            "source": "backend_rules",
            "created_at": now - timedelta(minutes=70)
        },
        {
            "event_type": "emergency",
            "message": "EMERGENCIA: Gas detectado por encima del límite seguro (165.0 ppm). Alarma y ventilación activadas.",
            "severity": "critical",
            "area": "control",
            "source": "backend_rules",
            "created_at": now - timedelta(minutes=30)
        },
        {
            "event_type": "arm64_analysis",
            "message": "Nuevo análisis ARM64 registrado para el módulo ANOMALY_DETECTION.",
            "severity": "info",
            "area": "control",
            "source": "raspi-01",
            "created_at": now - timedelta(minutes=10)
        }
    ]

    results["events"] = _seed_if_empty("events", events)
    
    # 4. Generar comandos remotos e internos simulados
    commands = [
        {
            "command": "set_mode",
            "target": "mode",
            "source": "web",
            "payload": {"state": "auto", "area": None},
            "created_at": now - timedelta(minutes=180)
        },
        {
            "command": "set_lights",
            "target": "lights",
            "source": "web",
            "payload": {"state": "on", "area": "control"},
            "created_at": now - timedelta(minutes=120)
        },
        {
            "command": "set_mode",
            "target": "mode",
            "source": "web",
            "payload": {"state": "manual", "area": None},
            "created_at": now - timedelta(minutes=90)
        },
        {
            "command": "set_pump",
            "target": "pump",
            "source": "web",
            "payload": {"state": "on", "area": "area_1"},
            "created_at": now - timedelta(minutes=85)
        },
        {
            "command": "set_mode",
            "target": "mode",
            "source": "web",
            "payload": {"state": "auto", "area": None},
            "created_at": now - timedelta(minutes=45)
        }
    ]

    results["commands"] = _seed_if_empty("commands", commands)
    
    # 5. Generar logs de actuación de hardware correspondientes
    actuator_logs = [
        {
            "actuator": "lights",
            "action": "on",
            "source": "web",
            "area": "control",
            "payload": {"state": "on"},
            "created_at": now - timedelta(minutes=120)
        },
        {
            "actuator": "pump",
            "action": "on",
            "source": "web",
            "area": "area_1",
            "payload": {"state": "on"},
            "created_at": now - timedelta(minutes=85)
        },
        {
            "actuator": "pump",
            "action": "off",
            "source": "backend_rules",
            "area": "area_1",
            "payload": {"state": "off"},
            "created_at": now - timedelta(minutes=45)
        },
        {
            "actuator": "fan",
            "action": "on",
            "source": "backend_rules",
            "area": "control",
            "payload": {"state": "on"},
            "created_at": now - timedelta(minutes=30)
        },
        {
            "actuator": "buzzer",
            "action": "on",
            "source": "backend_rules",
            "area": "control",
            "payload": {"state": "on"},
            "created_at": now - timedelta(minutes=30)
        }
    ]

    results["actuator_logs"] = _seed_if_empty("actuator_logs", actuator_logs)
    
    logger.info("Siembra de base de datos completada con éxito. "
                "(ARM64: seed no genera resultados — deben venir de ejecucion real)")
    return results


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    seed_database(clear_existing=True)
