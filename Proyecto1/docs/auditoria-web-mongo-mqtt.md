# Auditoría Web, MongoDB y MQTT

## Alcance

Esta auditoría cubre solo la parte web del enunciado y su integración con MongoDB y MQTT. No incluye la lógica ARM ni el firmware de la Raspberry Pi.

## Criterios del enunciado y estado actual

| Requisito del PDF | Estado | Observación |
| --- | --- | --- |
| Maqueta física con dos áreas y centro de control | Pendiente | El repositorio documenta la estructura, pero la maqueta física no se construye desde código. |
| Raspberry Pi 3 o 4 como unidad principal | Pendiente | El código queda preparado para la Pi, pero falta el hardware real. |
| Lógica de control en Python | Parcial | La base en Python ya existe; falta la lógica embebida completa de GPIO y sensores reales. |
| Sensores ambientales, de suelo, luz y gas | Parcial | El backend acepta y registra datos; falta la lectura física desde sensores reales. |
| Riego real con bomba o sistema equivalente | Pendiente | Hay contrato de control, pero no la activación física conectada. |
| Control automático de ventilación, iluminación, riego y alarmas | Parcial | El backend y la UI exponen los actuadores; falta automatización en la Pi. |
| MQTT para datos y comandos | Cumple a nivel backend | El backend publica comandos y deja el contrato listo para la Raspberry. |
| MongoDB Atlas para persistencia | Cumple | El modelo, endpoints y colección están definidos e implementados. |
| Dashboard web para monitoreo y control remoto | Cumple | La interfaz React/Tailwind ya está lista y funcional. |
| Pantalla LCD en el centro de control | Pendiente | Está documentada como parte del hardware, sin implementación física aún. |
| Botones físicos para control local | Pendiente | Deben implementarse en la Raspberry y cableado físico. |
| Registro de lecturas, eventos, estados y comandos | Cumple | El backend guarda y expone esos registros. |
| Video demostrativo y documentación técnica | Parcial | La documentación técnica está lista; falta el video demostrativo final. |

## Decisión técnica

- Backend: FastAPI.
- Frontend: React + Vite + Tailwind.
- Persistencia: MongoDB Atlas o MongoDB local en desarrollo.
- Mensajería: MQTT con tópico base configurable.

## Lectura correcta del alcance

Este repositorio deja cerrada la parte web + MongoDB + MQTT y el contrato para la Raspberry Pi. Lo que todavía requiere trabajo fuera del código es la maqueta física completa, la electrónica real y la validación final con hardware.

## Gaps reales

1. Definir y validar credenciales reales de MongoDB Atlas.
2. Apuntar `MQTT_HOST` al broker real.
3. Implementar el consumidor MQTT en la Raspberry Pi.
4. Conectar sensores, bomba, ventilación, luces, buzzer, LCD y botones reales a GPIO.
5. Probar el flujo extremo a extremo: web -> API -> MongoDB/MQTT -> Raspberry.
6. Grabar el video demostrativo con la maqueta funcionando.