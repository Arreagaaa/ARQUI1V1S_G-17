# Invernadero Inteligente IoT

Proyecto ACYE1 Grupo 17 para monitoreo y control de un invernadero con dos áreas de cultivo, centro de control, Raspberry Pi, MQTT, MongoDB y ARM64.

## Estado actual

- Backend FastAPI funcionando con MongoDB y rutas ARM64.
- Frontend React/Vite funcionando con dashboard y controles.
- Raspberry Pi app lista para MQTT y GPIO.
- ARM64 integrado y validado en QEMU.

## Arquitectura

```text
Sensores/Raspberry Pi -> MQTT -> Backend FastAPI -> MongoDB Atlas
Frontend React <-> Backend FastAPI
ARM64 (QEMU/RPi) -> arm_executor.py -> Backend -> MongoDB
```

## Permisos del proyecto

- Una sola bomba de agua / una sola válvula real.
- Segunda área de riego simulada manualmente en dashboard y lógica.
- Topics MQTT bajo `grupo17/invernadero/`.

## Verificación rápida

- `Proyecto1/backend`: API y persistencia.
- `Proyecto1/frontend`: dashboard web.
- `Proyecto1/raspberry`: GPIO, MQTT y ejecutor ARM64.
- `Proyecto1/arm64`: módulos de análisis y `lecturas.csv`.

## ARM64 validado

Los 5 módulos fueron probados en QEMU y sus resultados fueron enviados al backend y almacenados en MongoDB.
