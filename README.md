# Invernadero Inteligente IoT

Proyecto para **Arquitectura de Computadores y Ensambladores 1 (ACYE1)** — Grupo 17, Segundo Semestre 2026.

Monitoreo y control de un invernadero con dos áreas de cultivo y un centro de control, con Raspberry Pi, MQTT, MongoDB y módulos ARM64.

---

## Arquitectura

```
┌──────────────┐    MQTT (broker.emqx.io)   ┌──────────────┐   HTTP/REST   ┌──────────────┐
│ Raspberry Pi │ ◄────────────────────────► │   Backend    │ ◄───────────► │   Frontend   │
│ (sensores,   │   grupo17/invernadero/...          │   FastAPI    │               │ React + Vite │
│  actuadores) │                            └──────┬───────┘               └──────────────┘
└──────────────┘                                   │
                                               ┌────▼─────┐
                                               │ MongoDB  │
                                               │ Atlas    │
                                               └──────────┘
```

- **Raspberry Pi 3B+** — publica lecturas de sensores y suscribe comandos vía MQTT. 1 sola bomba + 2 válvulas selectoras (Área 1/Área 2), 3 LEDs de estado, LCD 16x2, 4 botones físicos.
- **Backend** — FastAPI; puente MQTT↔REST↔MongoDB; reglas automáticas de riego/ventilador/alarma.
- **Frontend** — Dashboard React con métricas en vivo (polling 15s), gráficos, controles manuales y sección ARM64.
- **MongoDB Atlas** — 6 colecciones: `sensor_readings`, `events`, `commands`, `system_status`, `actuator_logs`, `arm64_results`.

## Estructura del repositorio

```
ARQUI1V1S_G-17/
├── README.md                  # Este archivo (intro + setup rápido)
├── DEVELOPER_ONBOARDING.md    # Guía para un developer nuevo (clonar + verificación E2E + prompt IA)
└── Proyecto1/
    ├── ESTADO.md              # Cómo vamos, qué falta, roles, hitos
    ├── .env.example           # Plantilla de variables de entorno
    ├── backend/
    │   ├── BACKEND.md         # Endpoints REST, MQTT contract, servicios
    │   └── app/               # FastAPI: routers, services, mqtt/, db, seed
    ├── frontend/
    │   ├── FRONTEND.md        # Dashboard, componentes, polling
    │   └── src/               # React + Vite + Tailwind
    ├── raspberry/             # Cliente Python para la Pi (GPIO + MQTT + LCD + 4 botones)
    └── arm64/                 # Módulo 1 listo; módulos 2-5 con instrucciones pendientes
        ├── media.s            # ✅ Módulo 1 (media ponderada) — listo para QEMU
        ├── Makefile           # Compila utils + modulo1; targets 2-5 emiten "PENDIENTE"
        ├── lecturas.csv       # 30 lecturas reales (formato exacto del enunciado)
        └── utils/utils.s      # ⏳ Biblioteca común — tarea grupal
```

## Inicio rápido (Windows)

Abrir 2 terminales PowerShell:

**Terminal 1 — Backend** (puerto 8080):
```powershell
cd Proyecto1\backend
C:\Users\crjav\AppData\Local\Programs\Python\Python313\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8080 --no-access-log
```

**Terminal 2 — Frontend** (puerto 5173):
```powershell
cd Proyecto1\frontend
npm run dev
```

- Backend: `http://127.0.0.1:8080` (Swagger en `/docs`)
- Frontend: `http://localhost:5173`

Requisitos: Python 3.10+, Node 18+, MongoDB local en `:27017` o URI de Atlas en `backend/.env`.

## Inicio manual (Ubuntu)

```bash
# Backend
cd Proyecto1/backend
source .venv/bin/activate
uvicorn app.main:app --host 127.0.0.1 --port 8080 --no-access-log

# Frontend (otra terminal)
cd Proyecto1/frontend && npm run dev
```

> ⚠️ **No usar `--reload`**. Mata la conexión MQTT singleton y rompe la suscripción al broker.

## Verificar que todo funciona

Health-check: `curl http://127.0.0.1:8080/api/health` debe devolver `mongodb: true` y `mqtt_connected: true`.

Validación E2E completa con MQTTX Web (8 sub-pasos) en [DEVELOPER_ONBOARDING.md §TEST 6](DEVELOPER_ONBOARDING.md).

> **Nota:** Los scripts `test_regresion.py`, `test_mqttx_simulator.py` y `simulador.py` fueron eliminados en commit `697a99d`. La verificación E2E ahora es 100% manual con MQTTX Web (más cercano al uso real).

## MQTTX Web (cualquier persona puede participar)

> Prefijo MQTT: `grupo17/invernadero/` (prefijo del equipo, según permiso del auxiliar; sub-prefijo del árbol `invernadero/` del enunciado ACYE1 §4.2 para evitar colisiones en broker público).

1. Abrir MQTTX Web, conectar a `wss://broker.emqx.io:8084` (SSL/TLS ON), Client ID único.
2. Suscribirse a `grupo17/invernadero/#` para ver todo el tráfico del grupo.
3. Publicar en `grupo17/invernadero/control/remoto` con `source` propio (ej. `mqttx_jp` — nunca `web`, `api`, `backend`, `dashboard`).
4. Ejemplos de payloads y 8 sub-pasos de prueba E2E en [DEVELOPER_ONBOARDING.md §TEST 6](DEVELOPER_ONBOARDING.md).

## Documentación

| Archivo | Contenido |
|---|---|
| [DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md) | **Onboarding de un developer nuevo**: clonar, requisitos, 9 tests paso a paso, prompt para IA agent |
| [Proyecto1/ESTADO.md](Proyecto1/ESTADO.md) | Cómo vamos, qué falta, roles, hitos, flujo de trabajo |
| [Proyecto1/backend/BACKEND.md](Proyecto1/backend/BACKEND.md) | Endpoints REST, contrato MQTT, MQTTX Web, servicios, reglas |

## Repositorios de referencia

- `D:\Projects\USAC\ARQUI1_1S2026\01_PYTHON` — MQTTX, paho-mqtt, MongoDB, sensores
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64` — AArch64 assembly, arreglos, GDB
- `D:\Projects\USAC\ARQUI1_1S2026\03_RISCV` — RISC-V (fase futura)
