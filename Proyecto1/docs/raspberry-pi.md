# Guía de Raspberry Pi

Este documento deja lista la parte que correrá en la Raspberry Pi 3 cuando el hardware esté disponible.

## Objetivo

La Raspberry Pi debe hacer dos cosas:

1. Escuchar comandos publicados por el backend por MQTT.
2. Reportar lecturas, eventos, estado y logs al backend por HTTP.

## Contrato MQTT

- Tópico base: `MQTT_BASE_TOPIC`
- Comandos de actuadores: `MQTT_BASE_TOPIC/control/<actuator>`
- Comandos generales: `MQTT_BASE_TOPIC/commands`

Ejemplos de actuadores esperados:

- `pump`
- `fan`
- `lights`
- `buzzer`
- `mode`

## Variables de entorno

- `BACKEND_URL`: URL del backend, por ejemplo `http://localhost:8000`.
- `MQTT_HOST`: host del broker MQTT.
- `MQTT_PORT`: puerto del broker MQTT.
- `MQTT_USERNAME`: usuario del broker, si aplica.
- `MQTT_PASSWORD`: contraseña del broker, si aplica.
- `MQTT_BASE_TOPIC`: tópico base del proyecto.
- `DEVICE_ID`: identificador de la Raspberry.
- `ENABLE_GPIO`: `true` si ya estás usando hardware real.
- `POLL_INTERVAL_SECONDS`: intervalo para lecturas periódicas.
- `GPIO_PUMP_AREA_1`, `GPIO_PUMP_AREA_2`, `GPIO_FAN`, `GPIO_LIGHTS`, `GPIO_BUZZER`: pines sugeridos.

## Flujo esperado

1. El backend publica una orden en MQTT.
2. La Raspberry recibe el mensaje.
3. El controlador traduce la orden a GPIO.
4. La Raspberry registra el resultado en el backend.
5. Si hay lectura o evento nuevo, la Raspberry lo reporta al backend.

## Arranque

```bash
cd Proyecto1/raspberry
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python main.py
```