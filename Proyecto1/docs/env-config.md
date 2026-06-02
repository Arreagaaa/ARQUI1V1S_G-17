# Guía de variables de entorno

Este archivo reúne los bloques de entorno para backend, frontend y Raspberry Pi en un formato listo para copiar y adaptar.

## Backend

1. Copia `backend/.env.example` a `backend/.env`.
2. Usa `mongodb://localhost:27017` mientras trabajamos en local con Compass.
3. Si cambias de origen de frontend, actualiza `CORS_ORIGINS`.
4. El backend carga `backend/.env` automáticamente al iniciar.

```bash
MONGODB_URI=mongodb://localhost:27017
MONGODB_DB_NAME=invernadero_iot
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000
CORS_ORIGINS=http://localhost:5173
MQTT_HOST=localhost
MQTT_PORT=1883
MQTT_USERNAME=
MQTT_PASSWORD=
MQTT_BASE_TOPIC=invernadero
```

## Frontend

```bash
VITE_API_BASE_URL=http://localhost:8000
```

## Raspberry Pi

```bash
BACKEND_URL=http://localhost:8000
MQTT_HOST=localhost
MQTT_PORT=1883
MQTT_USERNAME=
MQTT_PASSWORD=
MQTT_BASE_TOPIC=invernadero
DEVICE_ID=raspi-01
ENABLE_GPIO=false
POLL_INTERVAL_SECONDS=15
GPIO_PUMP_AREA_1=17
GPIO_PUMP_AREA_2=27
GPIO_FAN=22
GPIO_LIGHTS=23
GPIO_BUZZER=24
LCD_RS=5
LCD_E=6
LCD_D4=12
LCD_D5=13
LCD_D6=19
LCD_D7=26
BUTTON_MODE=16
BUTTON_MANUAL=20
BUTTON_AUTO=21
```

## Recomendación

- Mantén el backend apuntando a MongoDB local y revisa las colecciones desde Compass mientras estás en etapa inicial.
- Cambia `MQTT_HOST` cuando pases del modo local al broker real.
- Activa `ENABLE_GPIO=true` solo cuando el cableado de la Raspberry esté terminado.

## Verificación rápida

1. Levanta el backend.
2. Consulta `GET /api/health`.
3. Confirma que `mongodb` responde `true`.
4. Si responde `false`, revisa que el servicio local de MongoDB esté corriendo y que Compass abra la URI correcta.