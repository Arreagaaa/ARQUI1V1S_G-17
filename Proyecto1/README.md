# Invernadero Inteligente IoT

Base de trabajo para la parte web del proyecto: backend en Python/FastAPI con persistencia en MongoDB Atlas y dashboard en React + Tailwind.

## Estructura

- `backend/`: API para lecturas, eventos, comandos y estado del sistema.
- `frontend/`: dashboard web para monitoreo y control.

## MongoDB

Colecciones previstas por el enunciado:

- `sensor_readings`
- `events`
- `commands`
- `system_status`
- `actuator_logs`

## Backend y control

El backend expone endpoints para:

- recibir lecturas, eventos y comandos,
- guardar estado del sistema y logs de actuadores,
- publicar comandos por MQTT,
- servir un resumen para el dashboard.

Variables de entorno del backend:

- `MONGODB_URI`
- `MONGODB_DB_NAME`
- `CORS_ORIGINS`
- `MQTT_HOST`
- `MQTT_PORT`
- `MQTT_USERNAME`
- `MQTT_PASSWORD`
- `MQTT_BASE_TOPIC`

Variables de entorno del frontend:

- `VITE_API_BASE_URL`

## Siguiente paso

1. Crear el entorno virtual del backend.
2. Instalar dependencias del frontend.
3. Conectar el backend con MongoDB Atlas.
4. Levantar el dashboard y consumir la API.

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

