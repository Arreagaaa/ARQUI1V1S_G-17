# Pendientes de Integración

## MongoDB

1. Crear o validar el cluster en Atlas.
2. Configurar usuario, password y whitelist de red.
3. Copiar la URI real en `backend/.env`.
4. Verificar que el backend responda `mongodb: true` en `/api/health`.

## MQTT

1. Levantar o definir el broker MQTT real.
2. Configurar `MQTT_HOST`, `MQTT_PORT`, `MQTT_USERNAME` y `MQTT_PASSWORD`.
3. Confirmar el tópico base `MQTT_BASE_TOPIC`.
4. Probar publicación desde `POST /api/control/{actuator}`.

## Raspberry Pi

1. Ajustar credenciales reales en `raspberry/.env`.
2. Validar el broker MQTT y los tópicos de control.
3. Conectar los GPIO reales a los pines definidos.
4. Probar el envío de lecturas y logs hacia el backend.
5. Validar el ciclo completo con la Raspberry Pi 3.

## Frontend

1. Dejar `VITE_API_BASE_URL` apuntando al backend correcto.
2. Probar el dashboard con datos reales de MongoDB.
3. Validar botones de control con el broker MQTT activo.

## Validación final

1. Correr backend y frontend.
2. Insertar una lectura de prueba.
3. Enviar un comando de prueba.
4. Confirmar persistencia en MongoDB.
5. Confirmar publicación MQTT.
6. Confirmar recepción en la Raspberry Pi.