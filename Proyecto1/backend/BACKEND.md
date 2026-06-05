# BACKEND — Invernadero IoT

FastAPI + paho-mqtt + pymongo. Sirve como puente MQTT↔REST↔MongoDB y aplica reglas automáticas de control.

---

## Arranque

```bash
cd Proyecto1/backend
pip install -r requirements.txt
cp ../.env.example .env
python -m uvicorn app.main:app --host 127.0.0.1 --port 8080
```

> ⚠️ **No usar `--reload`**. Mata la conexión MQTT singleton y rompe la suscripción al broker.

Variables de entorno (ver `Proyecto1/.env.example`):
```env
MONGODB_URI=mongodb://localhost:27017        # cambiar a Atlas cuando aplique
MONGODB_DB_NAME=invernadero_iot
CORS_ORIGINS=http://localhost:5173
ENABLE_MQTT=true
MQTT_HOST=broker.emqx.io
MQTT_PORT=1883
MQTT_BASE_TOPIC=grupo17/invernadero
```

---

## Estructura

```
backend/app/
├── main.py              # FastAPI entrypoint, CORS, lifespan, routers
├── config.py            # Settings (env vars)
├── db.py                # Conexión MongoDB + índices
├── schemas.py           # Modelos Pydantic (REST + MQTT)
├── seed.py              # Seeder de datos mock (idempotente)
├── routers/             # Endpoints REST
│   ├── sensors.py       # /api/sensors/*
│   ├── events.py        # /api/events
│   ├── commands.py      # /api/commands
│   ├── control.py       # /api/control/* (irrigation, lights, fan, alarm, mode)
│   ├── status.py        # /api/status
│   ├── arm64.py         # /api/arm64/* (mock gated por ?dev=true)
│   ├── actuator_logs.py # /api/actuator-logs
│   └── seed.py          # /api/seed
├── services/            # Lógica de negocio
│   ├── sensor_service.py    # Umbrales + reglas automáticas
│   └── control_service.py   # Ejecuta comandos + publica MQTT
└── mqtt/                # Capa MQTT desacoplada
    ├── connection_manager.py  # Singleton paho-mqtt (publish fire-and-forget)
    ├── topic_registry.py      # 15 topics del contrato
    ├── payload_validator.py   # Validación de payloads JSON
    ├── publisher.py           # Publica mensajes
    ├── subscriber.py          # MQTTSubscriber con 4 handlers
    └── mock_provider.py       # Datos mock para tests
```

---

## Endpoints REST

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/health` | `{status, mongodb, mqtt_connected, mqtt_subscriptions}` |
| GET | `/api/dashboard` | Resumen: status + recent_readings/events/commands/logs |
| GET | `/api/sensors/latest` | Últimas lecturas por sensor |
| GET | `/api/sensors/history` | Historial con `?source=&sensor_type=&area=&limit=&skip=` |
| POST | `/api/readings` | Insertar lectura de sensor |
| GET | `/api/events` | Eventos con `?severity=&type=&limit=` |
| POST | `/api/events` | Crear evento |
| GET | `/api/commands` | Comandos con `?source=&limit=&skip=` |
| POST | `/api/commands` | Crear comando (publica a MQTT si NO es auto-loop) |
| GET | `/api/actuator-logs` | Logs de actuadores con `?actuator=&limit=` |
| POST | `/api/actuator-logs` | Registrar log |
| GET | `/api/status` | Estado global actual |
| POST | `/api/system-status` | Actualizar estado global |
| POST | `/api/control/irrigation` | `{"action": "on\|off\|toggle"}` |
| POST | `/api/control/lights` | `{"action": "on\|off\|toggle"}` |
| POST | `/api/control/fan` | `{"action": "on\|off\|toggle"}` |
| POST | `/api/control/alarm` | `{"action": "on\|off\|toggle"}` |
| POST | `/api/control/mode` | `{"mode": "auto\|manual"}` |
| POST | `/api/control/{actuator}` | Legacy: `{"action": "on\|off"}` |
| GET | `/api/arm64/results` | Resultados por módulo |
| POST | `/api/arm64-results` | Registrar resultado |
| POST | `/api/arm64-results/mock` | Generar datos mock (dev) |
| POST | `/api/seed` | Inicializar DB (smart: respeta datos existentes) |
| POST | `/api/mqtt/reconnect` | Forzar reconexión MQTT |

Swagger interactivo: `http://127.0.0.1:8080/docs`

---

## Contrato MQTT

**Base:** `grupo17/invernadero/`
**Broker:** `broker.emqx.io` (puerto `1883` para Python/CLI sin SSL, `8084` WSS+SSL para MQTTX Web).
**Suscripciones backend:** `grupo17/invernadero/sensores/#`, `actuadores/#`, `control/#`, `estado/global`.

### 1. Sensores (la Raspberry Pi publica cada ~5s)

| Topic | sensor_type | unit | area |
|---|---|---|---|
| `sensores/temperatura` | `temperature` | `°C` | `control` |
| `sensores/humedad_aire` | `humidity` | `%` | `control` |
| `sensores/humedad_suelo_area1` | `soil_1` | `%` | `area_1` |
| `sensores/humedad_suelo_area2` | `soil_2` | `%` | `area_2` |
| `sensores/luz` | `light` | `%` | `control` |
| `sensores/gas` | `gas` | `ppm` | `control` |

Payload:
```json
{
  "sensor_type": "temperature",
  "value": 28.5,
  "unit": "°C",
  "area": "control",
  "status": "normal",
  "source": "raspi-01",
  "timestamp": "2026-06-03T11:20:00Z"
}
```

### 2. Actuadores (backend publica al cambiar)

Topics: `actuadores/bomba`, `actuadores/ventilador`, `actuadores/luces`, `actuadores/alarma`.
```json
{
  "actuator": "pump",
  "action": "on",
  "area": "area_1",
  "source": "raspi-01",
  "payload": { "pin": 17, "duration_seconds": 15 },
  "timestamp": "2026-06-03T11:20:05Z"
}
```

### 3. Control remoto (dashboard/MQTTX → backend)

Topic: `control/remoto`.
```json
{
  "command": "set_pump",
  "target": "pump",
  "source": "web",
  "payload": { "state": "on", "area": "area_1" },
  "timestamp": "2026-06-03T11:20:10Z"
}
```

Comandos válidos:

| Acción | command | target | payload.state |
|---|---|---|---|
| Riego área 1/2 ON/OFF | `set_pump` | `pump` | `on`/`off` + `area` |
| Luces | `set_lights` | `lights` | `on`/`off` |
| Ventilador | `set_fan` | `fan` | `on`/`off` |
| Alarma | `set_buzzer` | `buzzer` | `on`/`off`/`mute` |
| Modo | `set_mode` | `mode` | `auto`/`manual` |

### 4. Estado global (la Pi publica consolidado)

Topic: `estado/global`.
```json
{
  "mode": "auto",
  "overall_state": "NORMAL",
  "temperature": 24.5,
  "humidity": 55.0,
  "soil_1": 45.2,
  "soil_2": 42.1,
  "light": 60.0,
  "gas": 85.0,
  "pump_active": false,
  "fan_active": false,
  "lights_active": false,
  "buzzer_active": false,
  "source": "raspi-01",
  "timestamp": "2026-06-03T11:20:30Z"
}
```

`overall_state` válidos: `NORMAL`, `ADVERTENCIA`, `RIEGO_ACTIVO`, `MODO_MANUAL`, `EMERGENCIA`.

### Reglas del contrato
- `source` identifica al emisor. El backend Filtra `source in (web, api, backend, system, dashboard)` para evitar loops.
- `source` válidos para tráfico real: `raspi-01`, `raspi-sim-01`, `mqttx_*` (con inicial), `arm_executor`, `regression_test`.
- `timestamp` siempre ISO 8601 UTC.

---

## Reglas automáticas (modo `auto`)

`sensor_service.py` evalúa cada lectura y actualiza `system_status`:

| Condición | Estado global | Acción |
|---|---|---|
| Gas > 150 ppm | `EMERGENCIA` | ventilador ON + alarma ON |
| Temperatura > 30 °C | `ADVERTENCIA` | ventilador ON |
| Suelo < 30% | `RIEGO_ACTIVO` | bomba ON |
| Suelo > 80% | `ADVERTENCIA` | bomba OFF |
| Todo normal | `NORMAL` | desactivar emergencia |

Las acciones se persisten en `actuator_logs` y se publican en `actuadores/*` por MQTT.

---

## MongoDB — 6 colecciones obligatorias

| Colección | Contenido |
|---|---|
| `sensor_readings` | Lecturas con timestamp, sensor_type, value, unit, area, source |
| `events` | Eventos con severity, type, message, source |
| `commands` | Comandos manuales/auto con command, target, payload, source |
| `system_status` | Estado global actual (overall_state, mode, actuadores, valores) |
| `actuator_logs` | Log de cambios de actuadores (actuator, action, reason) |
| `arm64_results` | Resultados de módulos ARM64 (module, results dict, source) |

Índices creados al arrancar: `timestamp`, `sensor_type`, `source`, `module`, `severity`.

---

## Singleton MQTT

`mqtt/connection_manager.py` implementa un **singleton con `__new__`**:

- Una sola instancia por proceso.
- `publish()` es **fire-and-forget** (no espera `wait_for_publish()` desde handlers → evita deadlocks).
- Loguea cada `MQTT IN topic=... source=...` para diagnóstico.
- Suscripciones: `grupo17/invernadero/sensores/#`, `actuadores/#`, `control/#`, `estado/global`.
- Si el broker cae, `POST /api/mqtt/reconnect` fuerza la reconexión manual.

`POST /api/mqtt/reconnect` fuerza reconexión manual si se pierde la conexión.

---

## Filtro anti-loop

`sensor_service` y `event_service` ignoran mensajes cuyo `source` esté en `{web, api, backend, system, dashboard}`. Esto evita que un POST REST que publica por MQTT sea re-consumido y re-insertado.

---

## MQTTX Web — Guía paso a paso

Cualquier integrante puede monitorear y controlar el sistema con MQTTX Web, sin instalar nada.

### Conexión (WSS+SSL OBLIGATORIO)

> MQTTX Web **ya no soporta conexiones sin SSL**. Usá `wss://` en puerto 8084 con SSL/TLS activado.

| Campo | Valor |
|---|---|
| Host | `broker.emqx.io` |
| Port | `8084` |
| Protocol | `wss://` |
| Path | `/mqtt` |
| Username/Password | *(vacío)* |
| SSL/TLS | ✅ Activado |
| Clean Session | ✅ Activado |
| Keep Alive | `60` s |
| Client ID | `mqttx_invernadero_G17_<tu-inicial>_v<N>` (único por sesión) |

URL: https://mqttx.app/web

### Client ID único (evita sesión pegada)

El broker público guarda sesiones de clientes "muertos" con el mismo Client ID. Si publicás en MQTTX y el backend NO recibe, incrementá la versión:
- `mqttx_invernadero_G17_jp` → `..._v2` → `..._v3`

### Suscripción wildcard

Topic: `grupo17/invernadero/#` (QoS 0). Verás TODO el tráfico del grupo.

### Publicar un comando

Topic: `grupo17/invernadero/control/remoto`. Payload ejemplo:
```json
{
  "command": "set_pump",
  "target": "pump",
  "source": "mqttx_jp",
  "payload": { "state": "on", "area": "area_1" },
  "timestamp": "2026-06-04T00:00:00Z"
}
```

El backend recibe, persiste en `commands`, actualiza estado. Dashboard lo refleja en ≤15s.

### Diagnóstico

Para ver en tiempo real si el backend recibe tus mensajes, mirá la consola donde corre `uvicorn`:
```
[INFO] app.mqtt.connection_manager: MQTT IN topic=grupo17/invernadero/control/remoto qos=1 payload={...}
```

Si **no aparece**, el backend no recibió. Causas comunes:
1. **Sesión pegada** → Client ID `_v2`
2. **Topic incorrecto** → debe empezar con `grupo17/invernadero/...`
3. **JSON malformado** → comillas, comas
4. **QoS** → usar QoS 1

Si aparece "MQTT IN" pero no "MQTT command persistido", el `source` fue filtrado. NO uses `web`, `api`, `backend`, `system`, `dashboard` — usá `mqttx_<inicial>`.

### Alternativa 100% confiable: `test_mqttx_simulator.py`

Si MQTTX Web da problemas, este script Python simula lo mismo (mismo broker, mismos topics, mismo JSON, QoS 1) y es 100% confiable:
```bash
cd Proyecto1/backend
python test_mqttx_simulator.py  # 12 mensajes
```

---

## Tests

```bash
python test_regresion.py        # 45/45 OK: REST + Mongo + MQTT + reglas + filtro
python test_mqttx_simulator.py  # 12/12 OK: simula MQTTX (sensores, controles, emergencia)
python simulador.py --once      # publica 6 lecturas al broker
```

`test_regresion.py` cubre:
1. REST API (18 endpoints)
2. Control endpoints (irrigation, lights, fan, alarm, mode + status)
3. MongoDB 6 colecciones
4. MQTT subscriber (enabled, connected, suscripciones, reconnect)
5. Flujo MQTT E2E (publish sensor/command → lectura persistida)
6. Reglas automáticas (gas > 150 → ventilador + alarma + evento)
7. Filtro anti-loop (`source=api` NO se persiste)

### Escenarios de prueba del simulador

| Quieres probar | Comando |
|---|---|
| Estado normal | `python simulador.py` |
| Emergencia por gas | `python simulador.py --scenario emergencia` |
| Suelo seco Área 1 | `python simulador.py --scenario seco_area1` |
| Suelo saturado Área 2 | `python simulador.py --scenario saturado_area2` |
| Poca luz | `python simulador.py --scenario poca_luz` |
| Publicar una sola vez | `python simulador.py --once` |
| Cada 2 segundos | `python simulador.py --interval 2` |
