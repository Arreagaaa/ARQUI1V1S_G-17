# Configuración de MQTTX Web — Invernadero Inteligente (Grupo 17)

## Acceso

Abrir en el navegador: https://mqttx.app/web

## Nueva conexión

| Campo | Valor |
|-------|-------|
| Name | Invernadero Grupo 17 |
| Client ID | mqttx_invernadero_G17_monitor |
| Host | broker.hivemq.com |
| Port | 8884 |
| SSL/TLS | Activado |
| Protocol | wss |
| Username | (vacío) |
| Password | (vacío) |
| Keep Alive | 60 |
| Clean Session | Activado |

## Suscripciones para monitorear todo

Agregar la siguiente suscripción con wildcard:

- **Topic:** `grupo17/invernadero/#`
- **QoS:** 0

## Topics individuales para suscribir

| Categoría | Topic |
|-----------|-------|
| Temperatura | `grupo17/invernadero/sensores/temperatura` |
| Humedad ambiente | `grupo17/invernadero/sensores/humedad_ambiente` |
| Humedad suelo Área 1 | `grupo17/invernadero/sensores/humedad_suelo_area1` |
| Humedad suelo Área 2 | `grupo17/invernadero/sensores/humedad_suelo_area2` |
| Luz | `grupo17/invernadero/sensores/luz` |
| Gas | `grupo17/invernadero/sensores/gas` |
| Riego | `grupo17/invernadero/actuadores/riego` |
| Riego Área 1 | `grupo17/invernadero/actuadores/riego_area1` |
| Riego Área 2 | `grupo17/invernadero/actuadores/riego_area2` |
| Ventilador | `grupo17/invernadero/actuadores/ventilador` |
| Luces | `grupo17/invernadero/actuadores/luces` |
| Alarma | `grupo17/invernadero/actuadores/alarma` |
| Estado global | `grupo17/invernadero/estado/global` |
| Control remoto | `grupo17/invernadero/control/remoto` |
| Control manual | `grupo17/invernadero/control/manual` |

## Publicar un comando de prueba

- **Topic:** `grupo17/invernadero/control/remoto`
- **QoS:** 0
- **Payload (JSON):**
```json
{"comando": "RIEGO_AREA_1", "origen": "mqttx_test"}
```

## Prueba de escenarios desde MQTTX

### 1. Forzar riego Área 1
```json
{"command": "set_pump", "target": "pump", "source": "mqttx_manual", "payload": {"state": "on", "area": "area_1"}}
```

### 2. Forzar emergencia (gas alto)
```json
{"comando": "EMERGENCIA_GAS", "origen": "mqttx_manual"}
```

### 3. Cambiar modo manual
```json
{"command": "set_mode", "target": "mode", "source": "mqttx_manual", "payload": {"state": "manual"}}
```

## Formato de mensajes

### Sensores
```json
{
  "sensor_type": "temperature",
  "value": 28.5,
  "unit": "°C",
  "area": "control",
  "status": "normal",
  "source": "raspi-01",
  "timestamp": "2026-07-01T10:30:00Z"
}
```

### Comandos
```json
{
  "command": "set_pump",
  "target": "pump",
  "source": "dashboard",
  "payload": {"state": "on", "area": "area_1"},
  "timestamp": "2026-07-01T10:31:00Z"
}
```

## Notas importantes

- El broker es **público**: cualquier persona puede ver los mensajes si conoce el topic base `grupo17/invernadero/`.
- El Client ID debe ser **único** por sesión para evitar conflictos.
- Si hay problemas de conexión con HiveMQ, probar con:
  - **Broker:** `test.mosquitto.org`
  - **Puerto WSS:** `8081`
  - **URL:** `wss://test.mosquitto.org:8081/mqtt`
- Los mensajes publicados por MQTTX se reflejan en el dashboard y en MongoDB en tiempo real.
