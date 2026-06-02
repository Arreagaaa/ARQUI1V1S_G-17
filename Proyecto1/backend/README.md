# Backend

Framework: FastAPI.

Este backend sirve la API del proyecto de invernadero inteligente y concentra la persistencia en MongoDB, además del puente MQTT para control de actuadores.

## Variables de entorno

- `MONGODB_URI`: cadena de conexión a MongoDB local para Compass, por ejemplo `mongodb://localhost:27017`.
- `MONGODB_DB_NAME`: nombre de la base de datos.
- `CORS_ORIGINS`: orígenes permitidos para el frontend.
- `MQTT_HOST`: host del broker MQTT.
- `MQTT_PORT`: puerto del broker MQTT.
- `MQTT_USERNAME`: usuario del broker, si aplica.
- `MQTT_PASSWORD`: contraseña del broker, si aplica.
- `MQTT_BASE_TOPIC`: tópico base para publicar comandos.

## Colecciones

- `sensor_readings`
- `events`
- `commands`
- `system_status`
- `actuator_logs`

## Endpoints

- `GET /api/health`
- `GET /api/dashboard`
- `POST /api/readings`
- `POST /api/events`
- `POST /api/commands`
- `POST /api/system-status`
- `POST /api/actuator-logs`
- `POST /api/control/{actuator}`
- `GET /api/readings/latest`
- `GET /api/events/latest`
- `GET /api/commands/latest`
- `GET /api/actuator-logs/latest`

## Arranque

1. Copia `.env.example` a `.env`.
2. Verifica que MongoDB esté corriendo localmente y que Compass pueda abrir `mongodb://localhost:27017`.
3. Ajusta `MONGODB_DB_NAME` si vas a usar otro nombre de base.
4. Arranca el backend desde esta carpeta.

```bash
cd Proyecto1/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```