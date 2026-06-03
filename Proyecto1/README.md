# 🌿 Invernadero Inteligente IoT — Proyecto 1 ACYE1

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
                                 │  (Atlas)    │
                                 └────────────┘
```

## Estructura del repositorio

```
Proyecto1/
├── backend/              # API REST con FastAPI
│   ├── app/
│   │   ├── main.py       # Endpoints y lógica de negocio
│   │   ├── config.py     # Variables de entorno (pydantic-settings)
│   │   ├── db.py         # Conexión a MongoDB
│   │   ├── schemas.py    # Modelos Pydantic (validación)
│   │   └── mqtt_service.py # Servicio MQTT (desactivado por ahora)
│   └── requirements.txt
├── frontend/             # Dashboard web
│   └── src/
│       ├── App.tsx       # Componente principal (dashboard completo)
│       └── types.ts      # Tipos TypeScript
├── raspberry/            # Servicio Python para la Raspberry Pi 3B+
│   ├── main.py           # Lectura GPIO, lógica, publicación MQTT
│   └── requirements.txt
├── docs/                 # Contrato MQTT (referencia)
│   └── mqtt-contrato.md
├── .env.example          # Plantilla de variables de entorno
├── DEVELOPERS.md         # Guía técnica para el equipo
└── PENDIENTES.md         # Checklist de lo hecho y lo pendiente
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

## Endpoints principales del Backend

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/health` | Health-check (status + conexión MongoDB) |
| `GET` | `/api/dashboard` | Resumen completo para el dashboard |
| `POST` | `/api/readings` | Registrar lectura de sensor |
| `POST` | `/api/events` | Registrar evento |
| `POST` | `/api/commands` | Registrar comando |
| `POST` | `/api/system-status` | Actualizar estado global |
| `POST` | `/api/actuator-logs` | Registrar log de actuador |
| `POST` | `/api/control/{actuator}` | Controlar actuador (pump, fan, lights, buzzer, mode) |
| `GET` | `/api/readings/latest` | Últimas lecturas |
| `GET` | `/api/events/latest` | Últimos eventos |
| `GET` | `/api/commands/latest` | Últimos comandos |
| `GET` | `/api/actuator-logs/latest` | Últimos logs de actuadores |
| `GET` | `/api/arm64-results/latest` | Últimos resultados ARM64 |
| `POST` | `/api/arm64-results` | Registrar resultado ARM64 |
| `POST` | `/api/arm64-results/mock` | Generar datos de prueba ARM64 |

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
source .venv/bin/activate
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

### Variables de entorno

Copiar `.env.example` → `.env` y rellenar:

```env
MONGODB_URI=mongodb://localhost:27017
MONGODB_DB_NAME=greenhouse
CORS_ORIGINS=http://localhost:5173
ENABLE_MQTT=false
VITE_API_BASE_URL=http://127.0.0.1:8000
```

---

## Documentación relacionada

| Archivo | Contenido |
|---|---|
| [DEVELOPERS.md](DEVELOPERS.md) | Guía técnica para el equipo: ramas Git, tareas ARM64, integración |
| [PENDIENTES.md](PENDIENTES.md) | Checklist detallado: qué está hecho y qué falta |
| [docs/mqtt-contrato.md](docs/mqtt-contrato.md) | Contrato MQTT: topics, payloads, estados globales |
