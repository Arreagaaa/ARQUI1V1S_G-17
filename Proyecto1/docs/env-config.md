# Guía de variables de entorno

Este archivo reúne los bloques de entorno para backend, frontend y Raspberry Pi en un formato listo para copiar y adaptar.

## Backend

```bash
MONGODB_URI=mongodb+srv://<user>:<password>@<cluster>.mongodb.net/?retryWrites=true&w=majority
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

- Mantén el backend apuntando a MongoDB Atlas o a una instancia local según la etapa.
- Cambia `MQTT_HOST` cuando pases del modo local al broker real.
- Activa `ENABLE_GPIO=true` solo cuando el cableado de la Raspberry esté terminado.