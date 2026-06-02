# Auditoría Web, MongoDB y MQTT

## Alcance

Esta auditoría cubre solo la parte web del enunciado y su integración con MongoDB y MQTT. No incluye la lógica ARM ni el firmware de la Raspberry Pi.

## Criterios del enunciado y estado actual

| Requisito | Estado | Observación |
| --- | --- | --- |
| Dashboard web de monitoreo | Cumple | El frontend en React muestra estado, métricas y actividad reciente. |
| Persistencia en MongoDB | Cumple | El backend inserta y consulta las colecciones previstas. |
| Lecturas de sensores | Cumple | Existe endpoint para guardar lecturas y listarlas. |
| Eventos del sistema | Cumple | Existe endpoint para registrar eventos y mostrar el historial. |
| Comandos de control | Cumple | El backend guarda comandos y publica por MQTT. |
| Logs de actuadores | Cumple | Se registran logs de acciones sobre actuadores. |
| Estado del sistema | Cumple | Se guarda y consume el estado general del invernadero. |
| Dos áreas de cultivo | Parcial | La UI y el modelo ya contemplan área 1 y área 2, pero falta el flujo de hardware real. |
| Integración MQTT | Cumple a nivel backend | El backend publica mensajes; falta conectar el broker real y el consumidor en la Raspberry. |
| Conexión con Raspberry Pi | Pendiente | Hace falta el servicio real en la Pi que lea MQTT y ejecute GPIO. |

## Decisión técnica

- Backend: FastAPI.
- Frontend: React + Vite + Tailwind.
- Persistencia: MongoDB Atlas o MongoDB local en desarrollo.
- Mensajería: MQTT con tópico base configurable.

## Gaps reales

1. Definir y validar credenciales reales de MongoDB Atlas.
2. Apuntar `MQTT_HOST` al broker real.
3. Implementar el consumidor MQTT en la Raspberry Pi.
4. Conectar sensores y actuadores reales a GPIO.
5. Probar el flujo extremo a extremo: web -> API -> MongoDB/MQTT -> Raspberry.