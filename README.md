# Invernadero Inteligente IoT

Proyecto para **Arquitectura de Computadores y Ensambladores 1 (ACYE1)** — Grupo 17, Segundo Semestre 2026.

Monitoreo y control de un invernadero con dos áreas de cultivo y un centro de control, con Raspberry Pi, MQTT, MongoDB y módulos ARM64.

---

## Arquitectura

```
┌──────────────┐    MQTT (broker.emqx.io)   ┌──────────────┐   HTTP/REST   ┌──────────────┐
│ Raspberry Pi │ ◄────────────────────────► │   Backend    │ ◄───────────► │   Frontend   │
│ (sensores,   │   grupo17/invernadero/...  │   FastAPI    │               │ React + Vite │
│  actuadores) │                            └──────┬───────┘               └──────────────┘
└──────────────┘                                   │
                                              ┌────▼─────┐
                                              │ MongoDB  │
                                              │ Atlas    │
                                              └──────────┘
```

- **Raspberry Pi 3B+** — publica lecturas de sensores y suscribe comandos vía MQTT.
- **Backend** — FastAPI; puente MQTT↔REST↔MongoDB; reglas automáticas de riego/ventilador/alarma.
- **Frontend** — Dashboard React con métricas en vivo (polling 15s), gráficos, controles manuales y sección ARM64.
- **MongoDB Atlas** — 6 colecciones: `sensor_readings`, `events`, `commands`, `system_status`, `actuator_logs`, `arm64_results`.

## Estructura del repositorio

```
ARQUI1V1S_G-17/
├── README.md                  # Este archivo (intro + setup rápido)
├── DEVELOPER_ONBOARDING.md    # Guía para un developer nuevo (clonar + tests + prompt IA)
├── start.bat                  # Doble click en Windows: backend + frontend
└── Proyecto1/
    ├── ESTADO.md              # Cómo vamos, qué falta, roles, hitos
    ├── .env.example           # Plantilla de variables de entorno
    ├── backend/
    │   ├── BACKEND.md         # Endpoints REST, MQTT contract, servicios
    │   ├── app/               # FastAPI: routers, services, mqtt/, db, seed
    │   ├── simulador.py       # Publica lecturas al broker (simula la Pi)
    │   ├── test_regresion.py  # Suite 45 pruebas (API + Mongo + MQTT)
    │   └── test_mqttx_simulator.py  # Simula publicaciones MQTTX (12 mensajes)
    ├── frontend/
    │   ├── FRONTEND.md        # Dashboard, componentes, polling
    │   └── src/               # React + Vite + Tailwind
    ├── raspberry/             # Cliente Python para la Pi (GPIO + MQTT)
    └── arm64/                 # utils.s + 5 módulos por integrante + lecturas.csv
```

## Inicio rápido (Windows)

**Doble click** en `start.bat` (raíz). Abre backend y frontend en ventanas separadas.

- Backend: `http://127.0.0.1:8080` (Swagger en `/docs`)
- Frontend: `http://localhost:5173`

Requisitos: Python 3.10+, Node 18+, MongoDB local en `:27017` o URI de Atlas en `backend/.env`.

## Inicio manual

### Backend
```bash
cd Proyecto1/backend
pip install -r requirements.txt
cp ../.env.example .env
python -m uvicorn app.main:app --host 127.0.0.1 --port 8080
```

> ⚠️ **No usar `--reload`**. Mata la conexión MQTT singleton y rompe la suscripción al broker.

### Frontend
```bash
cd Proyecto1/frontend
npm install
echo "VITE_API_BASE_URL=http://localhost:8080" > .env.local
npm run dev
```

## Verificar que todo funciona

```bash
# Backend ya corriendo en :8080 con ENABLE_MQTT=true
cd Proyecto1/backend
python test_regresion.py        # esperado: 45 OK, 0 FAIL
python test_mqttx_simulator.py  # esperado: 12/12 publicados
python simulador.py --once      # publica 6 sensores al broker
```

Health-check: `curl http://127.0.0.1:8080/api/health` debe devolver `mongodb: true` y `mqtt_connected: true`.

## MQTTX Web (cualquier persona puede participar)

1. Abrir MQTTX Web, conectar a `wss://broker.emqx.io:8084` (SSL/TLS ON), Client ID único.
2. Suscribirse a `grupo17/invernadero/#` para ver todo el tráfico del grupo.
3. Publicar en `grupo17/invernadero/control/remoto` con `source` propio (ej. `mqttx_jp` — nunca `web`, `api`, `backend`).
4. Ver guía completa en [Proyecto1/docs/MQTTX_SETUP.md](Proyecto1/docs/MQTTX_SETUP.md).

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
