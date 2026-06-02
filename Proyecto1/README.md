# Invernadero Inteligente IoT

Base final de la parte web del proyecto: backend en Python con FastAPI, persistencia en MongoDB Atlas y dashboard en React + Vite + Tailwind.

## Alcance

Este repositorio cubre solo la parte web + MongoDB + MQTT del enunciado. La integración con la Raspberry Pi queda documentada como siguiente paso técnico.

## Estructura

- `backend/`: API para lecturas, eventos, comandos, estado del sistema y logs de actuadores.
- `frontend/`: dashboard web para monitoreo y control.
- `raspberry/`: servicio base para la Raspberry Pi con MQTT y GPIO preparado.
- `docs/`: auditoría y pendientes de integración.

## MongoDB

Colecciones previstas por el enunciado:

- `sensor_readings`
- `events`
- `commands`
- `system_status`
- `actuator_logs`

## Backend

Framework: FastAPI.

El backend expone endpoints para:

- recibir lecturas, eventos y comandos,
- guardar estado del sistema y logs de actuadores,
- publicar comandos por MQTT,
- servir un resumen para el dashboard,
- verificar la conexión a MongoDB.

Variables de entorno del backend:

- `MONGODB_URI`
- `MONGODB_DB_NAME`
- `CORS_ORIGINS`
- `MQTT_HOST`
- `MQTT_PORT`
- `MQTT_USERNAME`
- `MQTT_PASSWORD`
- `MQTT_BASE_TOPIC`

## Frontend

Variables de entorno del frontend:

- `VITE_API_BASE_URL`

## Documentación

- [Auditoría de cumplimiento](docs/auditoria-web-mongo-mqtt.md)
- [Guía de variables de entorno](docs/env-config.md)
- [Guía de backend](backend/README.md)
- [Guía de frontend](frontend/README.md)
- [Guía de Raspberry Pi](docs/raspberry-pi.md)
- [Checklist física de Raspberry Pi](docs/checklist-pi.md)
- [Pendientes de integración](docs/pendientes.md)

## Arranque local

Backend:

```bash
cd Proyecto1/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Frontend:

```bash
cd Proyecto1/frontend
pnpm install
pnpm dev
```

