"""
Capa de acceso a base de datos MongoDB.

Patrón: Database Factory + Adapter
=============================================
Para migrar de MongoDB local a Atlas, solo es necesario cambiar la variable
de entorno MONGODB_URI. El código no requiere ninguna modificación.

Ejemplo de URI para MongoDB Atlas:
  mongodb+srv://usuario:password@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority

Colecciones del sistema:
  - sensor_readings: Lecturas de sensores (temperatura, humedad, suelo, luz, gas)
  - events: Eventos del sistema (alertas, cambios de estado, errores)
  - commands: Comandos enviados desde el dashboard o MQTT
  - system_status: Estado global actual del sistema (último snapshot)
  - actuator_logs: Logs de activación de actuadores (bomba, ventilador, luces, alarma)
  - arm64_results: Resultados de análisis estadístico ARM64
"""

import logging
from functools import lru_cache

from pymongo import MongoClient, ASCENDING, DESCENDING
from pymongo.database import Database

from .config import get_settings

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Database Factory — Adaptador transparente para local o Atlas
# ---------------------------------------------------------------------------

@lru_cache(maxsize=1)
def get_client() -> MongoClient:
    """
    Crea y cachea el cliente MongoDB.

    El cliente detecta automáticamente si la URI apunta a una instancia local
    o a MongoDB Atlas (mongodb+srv://). No se requieren cambios de código.
    """
    settings = get_settings()
    logger.info("Conectando a MongoDB: %s", settings.mongodb_uri[:30] + "...")
    return MongoClient(
        settings.mongodb_uri,
        # Opciones recomendadas para Atlas y compatibilidad local
        serverSelectionTimeoutMS=5000,
        connectTimeoutMS=10000,
        retryWrites=True,
    )


def get_database() -> Database:
    """Retorna la base de datos configurada."""
    settings = get_settings()
    return get_client()[settings.mongodb_db_name]


def ping_mongodb() -> bool:
    """Verifica la conectividad con MongoDB."""
    try:
        get_client().admin.command("ping")
        return True
    except Exception as exc:
        logger.warning("MongoDB ping failed: %s", exc)
        return False


# ---------------------------------------------------------------------------
# Índices — Se crean al iniciar la aplicación
# ---------------------------------------------------------------------------

def touch_indexes() -> None:
    """
    Crea índices optimizados para todas las colecciones del sistema.

    Los índices garantizan rendimiento en las consultas más frecuentes:
    - Lecturas por tipo de sensor y fecha
    - Eventos por fecha y severidad
    - Comandos por fecha
    - Estado del sistema por fecha (último)
    - Logs de actuadores por fecha y tipo
    - Resultados ARM64 por módulo y fecha
    """
    try:
        db = get_database()

        # sensor_readings — consultas por tipo, área y fecha
        db.sensor_readings.create_index(
            [("sensor_type", ASCENDING), ("recorded_at", DESCENDING)],
            name="idx_sensor_type_date",
        )
        db.sensor_readings.create_index(
            [("area", ASCENDING), ("recorded_at", DESCENDING)],
            name="idx_area_date",
        )
        db.sensor_readings.create_index(
            [("recorded_at", DESCENDING)],
            name="idx_recorded_at",
        )

        # events — consultas por fecha y severidad
        db.events.create_index(
            [("created_at", DESCENDING)],
            name="idx_events_date",
        )
        db.events.create_index(
            [("severity", ASCENDING), ("created_at", DESCENDING)],
            name="idx_events_severity_date",
        )
        db.events.create_index(
            [("event_type", ASCENDING), ("created_at", DESCENDING)],
            name="idx_events_type_date",
        )

        # commands — consultas por fecha
        db.commands.create_index(
            [("created_at", DESCENDING)],
            name="idx_commands_date",
        )

        # system_status — último estado
        db.system_status.create_index(
            [("updated_at", DESCENDING)],
            name="idx_status_date",
        )

        # actuator_logs — consultas por actuador y fecha
        db.actuator_logs.create_index(
            [("created_at", DESCENDING)],
            name="idx_actuator_logs_date",
        )
        db.actuator_logs.create_index(
            [("actuator", ASCENDING), ("created_at", DESCENDING)],
            name="idx_actuator_logs_type_date",
        )

        # arm64_results — consultas por módulo y fecha
        db.arm64_results.create_index(
            [("created_at", DESCENDING)],
            name="idx_arm64_date",
        )
        db.arm64_results.create_index(
            [("module", ASCENDING), ("created_at", DESCENDING)],
            name="idx_arm64_module_date",
        )

        logger.info("Índices de base de datos creados/verificados correctamente.")

    except Exception as exc:
        logger.error("Error creando índices de base de datos: %s", exc)
