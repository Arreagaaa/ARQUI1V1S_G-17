# Invernadero Inteligente IoT — Proyecto 1 ACYE1

Sistema de monitoreo y control de un invernadero inteligente con dos áreas de cultivo y un centro de control. Proyecto para **Arquitectura de Computadores y Ensambladores 1 (ACYE1)**, Segundo Semestre 2026.

---

## Arquitectura general

```
┌─────────────┐      MQTT       ┌──────────────┐     HTTP/REST    ┌───────────────┐
│ Raspberry Pi │ ──────────────▸ │   Backend    │ ◂─────────────▸ │   Frontend    │
│ (sensores,   │ ◂────────────── │   FastAPI    │                 │ React + Vite  │
│  actuadores) │                 └──────┬───────┘                 └───────────────┘
└─────────────┘                        │
                                  ┌─────▼──────┐
                                  │  MongoDB    │
                                  │  (local)    │
                                  └────────────┘
```

## Estado actual del proyecto

| Componente | Estado |
|---|---|
| Backend FastAPI (todos los endpoints) | COMPLETO |
| Frontend React (dashboard, gráficos, controles) | COMPLETO |
| MongoDB local (6 colecciones, índices, seed) | COMPLETO |
| Arquitectura MQTT (desacoplada, preparada) | COMPLETO |
| ARM64 estructura (módulos, utils, resultados) | PREPARADO |
| Conexión MQTT real vía MQTTX Web | PENDIENTE |
| MongoDB Atlas | PENDIENTE |
| Hardware físico (Raspberry Pi, sensores, actuadores) | PENDIENTE |

## Estructura del repositorio

```
Proyecto1/
├── backend/              # API REST con FastAPI
│   ├── app/
│   │   ├── main.py           # Entrypoint, CORS, lifespan, routers
│   │   ├── config.py         # Configuración centralizada (Settings)
│   │   ├── db.py             # Conexión MongoDB (local/Atlas), índices
│   │   ├── schemas.py        # Modelos Pydantic (API + MQTT payloads)
│   │   ├── seed.py           # Seeder de datos mock para MongoDB
│   │   ├── mqtt_service.py   # Legacy MQTT wrapper
│   │   ├── mqtt/             # Capa MQTT desacoplada
│   │   │   ├── connection_manager.py
│   │   │   ├── topic_registry.py
│   │   │   ├── payload_validator.py
│   │   │   ├── publisher.py
│   │   │   ├── subscriber.py
│   │   │   └── mock_provider.py
│   │   ├── routers/          # Endpoints REST modulares
│   │   │   ├── sensors.py
│   │   │   ├── events.py
│   │   │   ├── commands.py
│   │   │   ├── control.py
│   │   │   ├── status.py
│   │   │   ├── arm64.py
│   │   │   └── actuator_logs.py
│   │   └── services/         # Lógica de negocio
│   │       ├── sensor_service.py
│   │       └── control_service.py
│   └── requirements.txt
├── frontend/             # Dashboard web
│   ├── src/
│   │   ├── App.tsx           # Dashboard completo (métricas, gráficos, controles)
│   │   ├── types.ts          # Tipos TypeScript
│   │   └── lib/api.ts        # Cliente API REST
│   └── package.json
├── raspberry/            # Servicio Python para la Raspberry Pi 3B+
│   ├── main.py               # Lectura GPIO, lógica, publicación MQTT
│   └── requirements.txt
├── arm64/                # Módulos ARM64 (AArch64 Assembly)
│   ├── lecturas.csv          # 30 lecturas de prueba (6 tipos de sensor)
│   ├── utils/                # Biblioteca común utils.s (placeholder)
│   ├── modules/              # 5 módulos individuales (cada integrante)
│   │   ├── modulo_1_media/
│   │   ├── modulo_2_varianza/
│   │   ├── modulo_3_anomalias/
│   │   ├── modulo_4_prediccion/
│   │   └── modulo_5_tendencia/
│   └── results/              # Salidas de los módulos (.txt)
├── docs/
│   └── mqtt-contrato.md      # Contrato MQTT oficial
├── .env.example              # Plantilla de variables de entorno
├── DEVELOPERS.md             # Guía técnica para el equipo
└── PENDIENTES.md             # Checklist de avance
```

## Colecciones en MongoDB

| Colección | Propósito |
|---|---|
| `sensor_readings` | Lecturas de sensores (temperatura, humedad, suelo, luz, gas) |
| `events` | Eventos del sistema (advertencias, emergencias, restauraciones) |
| `commands` | Comandos enviados desde el dashboard hacia la Pi |
| `system_status` | Estado global actual (modo, actuadores, valores) |
| `actuator_logs` | Log de activaciones/desactivaciones de actuadores |
| `arm64_results` | Resultados de los 5 módulos ARM64 |

## Endpoints del Backend

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/health` | Health-check (status + conexión MongoDB) |
| `GET` | `/api/dashboard` | Resumen completo para el dashboard |
| `GET` | `/api/sensors/latest` | Últimas lecturas de sensores |
| `GET` | `/api/sensors/history` | Historial con filtros y paginación |
| `POST` | `/api/readings` | Registrar lectura de sensor |
| `GET` | `/api/events` | Listar eventos con filtros |
| `POST` | `/api/events` | Crear evento |
| `GET` | `/api/commands` | Listar comandos |
| `POST` | `/api/commands` | Crear comando |
| `GET` | `/api/actuator-logs` | Listar logs de actuadores |
| `POST` | `/api/actuator-logs` | Registrar log de actuador |
| `GET` | `/api/status` | Estado global actual del sistema |
| `POST` | `/api/system-status` | Registrar/actualizar estado |
| `POST` | `/api/control/irrigation` | Controlar riego (bomba) |
| `POST` | `/api/control/lights` | Controlar luces LED |
| `POST` | `/api/control/fan` | Controlar ventilador |
| `POST` | `/api/control/alarm` | Controlar alarma (buzzer) |
| `POST` | `/api/control/mode` | Cambiar modo auto/manual |
| `POST` | `/api/control/{actuator}` | Control legacy por actuador |
| `GET` | `/api/arm64/results` | Resultados ARM64 por módulo |
| `POST` | `/api/arm64-results` | Registrar resultado ARM64 |
| `POST` | `/api/arm64-results/mock` | Generar datos mock ARM64 |
| `POST` | `/api/seed` | Inicializar DB con datos mock |

## Reglas automáticas (modo `auto`)

El backend evalúa cada lectura y actualiza el estado global:

| Condición | Estado | Acción |
|---|---|---|
| Gas > 150 ppm | `EMERGENCIA` | Activa ventilador + alarma |
| Temperatura > 30 °C | `ADVERTENCIA` | Activa ventilador |
| Suelo < 30% | `RIEGO_ACTIVO` | Activa bomba de riego |
| Suelo > 80% | `ADVERTENCIA` | Desactiva bomba |
| Todo normal | `NORMAL` | Desactiva actuadores de emergencia |

## Arranque local

### Backend
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

### Frontend
```bash
cd frontend
pnpm install
pnpm dev
```

- Dashboard: `http://localhost:5173`
- API Swagger: `http://localhost:8000/docs`
- API OpenAPI: `http://localhost:8000/openapi.json`

### Requisitos
- Python 3.10+ con pip
- Node.js 18+ con pnpm
- MongoDB local (Compass) en `mongodb://localhost:27017`

### Variables de entorno
```env
MONGODB_URI=mongodb://localhost:27017
MONGODB_DB_NAME=invernadero_iot
CORS_ORIGINS=http://localhost:5173
ENABLE_MQTT=false
VITE_API_BASE_URL=http://127.0.0.1:8000
```

## Documentación relacionada

| Archivo | Contenido |
|---|---|
| [DEVELOPERS.md](DEVELOPERS.md) | Guía técnica para el equipo |
| [PENDIENTES.md](PENDIENTES.md) | Checklist detallado del avance |
| [docs/mqtt-contrato.md](docs/mqtt-contrato.md) | Contrato MQTT: topics, payloads, estados |
