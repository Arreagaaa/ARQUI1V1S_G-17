# Reporte de Configuración MQTT — Invernadero Inteligente (Grupo 17)

## 1. Broker Configurado

| Propiedad | Valor |
|-----------|-------|
| Host | `broker.hivemq.com` |
| Puerto TCP | 1883 (backend Python) |
| Puerto SSL/TCP | 8883 |
| Puerto WSS | 8884 (frontend browser, MQTTX Web) |
| URL WebSocket | `wss://broker.hivemq.com:8884/mqtt` |
| Protocolo | MQTT v3.1.1 / v5 |
| Autenticación | No requiere (broker público) |

**Alternativa configurada:** `broker.emqx.io` (TCP :1883, WSS :8084)

## 2. Topics Activos

### Publicación (Backend → Broker)

| Topic | Tipo | Descripción |
|-------|------|-------------|
| `grupo17/invernadero/sensores/temperatura` | Publica | Lecturas de temperatura |
| `grupo17/invernadero/sensores/humedad_ambiente` | Publica | Lecturas de humedad |
| `grupo17/invernadero/sensores/humedad_suelo_area1` | Publica | Humedad suelo área 1 |
| `grupo17/invernadero/sensores/humedad_suelo_area2` | Publica | Humedad suelo área 2 |
| `grupo17/invernadero/sensores/luz` | Publica | Nivel de luz |
| `grupo17/invernadero/sensores/gas` | Publica | Nivel de gas |
| `grupo17/invernadero/actuadores/riego` | Publica | Estado riego general |
| `grupo17/invernadero/actuadores/riego_area1` | Publica | Estado riego área 1 |
| `grupo17/invernadero/actuadores/riego_area2` | Publica | Estado riego área 2 |
| `grupo17/invernadero/actuadores/ventilador` | Publica | Estado ventilador |
| `grupo17/invernadero/actuadores/luces` | Publica | Estado luces |
| `grupo17/invernadero/actuadores/alarma` | Publica | Estado alarma (buzzer) |
| `grupo17/invernadero/estado/global` | Publica | Estado global del sistema |

### Suscripción (Backend ← Broker)

| Topic | Tipo | Descripción |
|-------|------|-------------|
| `grupo17/invernadero/sensores/#` | Suscribe | Lecturas de sensores |
| `grupo17/invernadero/actuadores/#` | Suscribe | Eventos de actuadores |
| `grupo17/invernadero/control/#` | Suscribe | Comandos de control remoto |
| `grupo17/invernadero/estado/global` | Suscribe | Estado global reportado |

### Frontend (MQTT WebSocket directo)

| Topic | Dirección | Propósito |
|-------|-----------|-----------|
| `grupo17/invernadero/sensores/#` | Suscribe | Actualización en tiempo real del dashboard |
| `grupo17/invernadero/estado/global` | Suscribe | Estado global en tiempo real |
| `grupo17/invernadero/control/remoto` | Publica | Envío de comandos desde controles |

## 3. Pruebas Ejecutables

### Prueba 1 — Publicación de sensores
1. `cd Proyecto1/backend && python3 simulador.py`
2. Abrir MQTTX Web → suscribir a `grupo17/invernadero/#`
3. ✅ Se reciben mensajes cada 5 segundos en todos los topics de sensores
4. ✅ Datos aparecen en MongoDB `sensor_readings`
5. ✅ Dashboard se actualiza (polling + MQTT directo)

### Prueba 2 — Comando desde dashboard
1. Click "Bomba Área 1 ON" en el dashboard
2. ✅ MQTTX Web recibe `grupo17/invernadero/control/remoto`
3. ✅ Backend procesa comando
4. ✅ Estado cambia a `RIEGO_ACTIVO`
5. ✅ Comando en MongoDB `commands`
6. ✅ Evento en MongoDB `events`

### Prueba 3 — Comando desde MQTTX Web
1. Publicar en `grupo17/invernadero/control/remoto`:
   ```json
   {"command": "set_pump", "target": "pump", "source": "mqttx_manual", "payload": {"state": "on", "area": "area_1"}}
   ```
2. ✅ Backend procesa el comando
3. ✅ Estado global cambia a `RIEGO_ACTIVO`
4. ✅ Dashboard muestra alerta
5. ✅ Evento en MongoDB `events`

### Prueba 4 — Escenario completo simulado
1. `python3 simulador.py --scenario seco_area_1`
2. ✅ Sistema detecta humedad baja en Área 1 (<30%)
3. ✅ Activa riego (pump_active=true)
4. ✅ Estado cambia a `RIEGO_ACTIVO`
5. ✅ Al normalizar humedad, riego se desactiva

## 4. Latencia Observada

| Componente | Latencia |
|------------|----------|
| Simulador → MQTT → Backend → MongoDB | <500ms |
| Dashboard REST polling | 15s (configurable) |
| Dashboard MQTT directo (WebSocket) | <200ms |
| MQTTX Web → Backend → MongoDB | <500ms |

## 5. Problemas Conocidos / Consideraciones

| Issue | Descripción | Solución |
|-------|-------------|----------|
| Broker público | Cualquiera puede ver mensajes si conoce el topic | Solo para desarrollo; en producción usar broker propio |
| Client ID único | Si dos sesiones usan el mismo ID, una se desconecta | Cada instancia usa `clientId_TIMESTAMP` |
| WebSocket CORS | Algunos brokers pueden bloquear WebSocket desde browser | HiveMQ y EMQX permiten conexiones browser sin restricciones |
| Reconexión | Si el broker se cae, paho reconecta automáticamente | Configurado con reconnect_delay_set |

## 6. Instrucciones para el Equipo

Cada integrante debe:

1. **Abrir MQTTX Web** en https://mqttx.app/web
2. **Configurar conexión:**
   - Name: `Invernadero Grupo 17`
   - Client ID: `mqttx_invernadero_G17_<nombre_integrante>`
   - Host: `broker.hivemq.com`
   - Port: `8884`
   - SSL/TLS: Activado
   - Protocol: `wss`
3. **Suscribir a:** `grupo17/invernadero/#`
4. **Verificar recepción** de mensajes del simulador
5. **Publicar comandos de prueba** en `grupo17/invernadero/control/remoto`
6. **Verificar cambios** en el dashboard (http://localhost:5173)
7. **Verificar datos** en MongoDB Compass (mongodb://localhost:27017/invernadero_iot)
