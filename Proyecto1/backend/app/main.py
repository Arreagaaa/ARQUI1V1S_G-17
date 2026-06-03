"""
Invernadero Inteligente IoT API — Entrypoint Principal.

Inicializa la aplicación FastAPI, configura middleware CORS,
gestiona el ciclo de vida (lifespan) para conexiones de base de datos
y broker MQTT, y registra todos los routers del sistema modular.
"""

import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .db import touch_indexes
from .mqtt.connection_manager import MQTTConnectionManager
from .routers import sensors, events, commands, control, status, arm64, actuator_logs

# Configurar logging básico
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gestor del ciclo de vida de la aplicación FastAPI.
    Reemplaza los eventos obsoletos 'startup' y 'shutdown'.
    """
    logger.info("Iniciando aplicación Invernadero Inteligente IoT...")
    
    # 1. Asegurar la creación de índices en la base de datos MongoDB
    try:
        touch_indexes()
        logger.info("Índices de base de datos validados/creados.")
    except Exception as exc:
        logger.error("Error al inicializar índices de base de datos: %s", exc)

    # 2. Conectar al broker MQTT si está habilitado
    mqtt_manager = MQTTConnectionManager()
    if mqtt_manager.is_enabled:
        logger.info("MQTT habilitado. Conectando al broker en %s:%s...", 
                    mqtt_manager._host, mqtt_manager._port)
        mqtt_manager.connect()
    else:
        logger.info("MQTT deshabilitado en la configuración. Modo dry-run activo.")

    yield  # La aplicación corre aquí

    # 3. Limpieza al apagar la aplicación
    logger.info("Apagando aplicación...")
    if mqtt_manager.is_enabled:
        mqtt_manager.disconnect()
    logger.info("Aplicación apagada correctamente.")


# Inicializar la aplicación con lifespan
app = FastAPI(
    title="Invernadero Inteligente IoT API",
    description="API de monitoreo y control para el sistema de invernadero inteligente (PRE-ARM y PRE-MAQUETA)",
    version="1.0.0",
    lifespan=lifespan,
)

settings = get_settings()

# Habilitar CORS para permitir solicitudes desde el frontend (React/Vite)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Endpoint de salud en el entrypoint principal para verificación rápida
@app.get("/api/health", tags=["Sistema"])
def health():
    """Verificación básica de salud de la API."""
    from .db import ping_mongodb
    from datetime import datetime, timezone
    return {
        "status": "ok",
        "mongodb": ping_mongodb(),
        "timestamp": datetime.now(timezone.utc),
    }

# Registrar Routers Modulares
app.include_router(sensors.router)
app.include_router(events.router)
app.include_router(commands.router)
app.include_router(control.router)
app.include_router(status.router)
app.include_router(arm64.router)
app.include_router(actuator_logs.router)
