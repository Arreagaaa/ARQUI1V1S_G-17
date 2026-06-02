# Guía de Raspberry Pi

Este documento deja lista la parte que correrá en la Raspberry Pi 3 cuando el hardware esté disponible.

## Objetivo

La Raspberry Pi debe hacer dos cosas:

1. Escuchar comandos publicados por el backend por MQTT.
2. Reportar lecturas, eventos, estado y logs al backend por HTTP.

Además, debe quedar lista para el centro de control físico con LCD y botones.

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
- `LCD_RS`, `LCD_E`, `LCD_D4`, `LCD_D5`, `LCD_D6`, `LCD_D7`: pines sugeridos para la pantalla LCD.
- `BUTTON_MODE`, `BUTTON_MANUAL`, `BUTTON_AUTO`: pines sugeridos para botones físicos.

Para ver un bloque de ejemplo ordenado por componente, consulta [Guía de variables de entorno](env-config.md). Para la conexión física y pines sugeridos, consulta [Checklist física de Raspberry Pi](checklist-pi.md).

## Flujo esperado

1. El backend publica una orden en MQTT.
2. La Raspberry recibe el mensaje.
3. El controlador traduce la orden a GPIO.
4. La Raspberry registra el resultado en el backend.
5. Si hay lectura o evento nuevo, la Raspberry lo reporta al backend.

## Centro de control

- La pantalla LCD debe mostrar estado general, modo actual y alertas.
- Los botones físicos deben permitir cambio de modo y acciones locales básicas.
- Estos elementos quedan como contrato documentado para el cableado final.

## Arranque

```bash
cd Proyecto1/raspberry
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python main.py
```