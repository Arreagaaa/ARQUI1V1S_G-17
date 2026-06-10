# Invernadero Inteligente IoT — Grupo 17

Monitoreo y control de un invernadero con dos áreas de cultivo usando Raspberry Pi, sensores físicos, MQTT, FastAPI, MongoDB, ARM64 assembly y dashboard web.

## Arquitectura

```
Sensores/Raspberry Pi → MQTT (broker.hivemq.com) → Backend FastAPI → MongoDB
Frontend React (Vite)  ← REST API + MQTT WS ← Backend FastAPI
ARM64 (QEMU/RPi)       → arm_executor.py      → Backend → MongoDB
```

## Estructura del proyecto

| Directorio | Contenido |
|---|---|
| `backend/` | FastAPI + MongoDB + MQTT client + simulador |
| `frontend/` | Dashboard React con Vite, Tailwind, MQTT WebSocket |
| `arm64/` | 5 módulos en ARM64 assembly (media, varianza, anomalías, predicción, tendencia) |
| `raspberry/` | Código embebido para Raspberry Pi (GPIO, MQTT, LCD, botones, ejecutor ARM64) |

## Requisitos

- Python 3.10+
- Node.js 18+ / pnpm
- MongoDB (local o Atlas)
- `aarch64-linux-gnu-as` y `qemu-aarch64` (para ARM64)

## Links

- **Frontend:** http://localhost:5173
- **Backend API:** http://localhost:8000/docs
- **Health:** http://localhost:8000/api/health

## Setup rápido

```bash
# Backend
cd Proyecto1/backend && pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000

# Frontend (otra terminal)
cd Proyecto1/frontend && pnpm install && pnpm dev
```

Ver `Proyecto1/SETUP.md` para instrucciones detalladas (simulador, ARM64, MQTTX, Raspberry Pi, wiring).
