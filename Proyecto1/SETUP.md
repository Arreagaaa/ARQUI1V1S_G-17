# SETUP — Como correr todo el proyecto

## Arquitectura (local)

```
LAPTOP (WSL)                          RASPBERRY PI (red local)
┌──────────────┐                     ┌──────────────────────┐
│  Frontend     │  ──HTTP──>         │  Backend (FastAPI)    │
│  (Vite 5173)  │                    │  (uvicorn :8000)      │
└──────────────┘                    │  MongoDB Atlas        │
                                     │  MQTT                 │
                                     │  main.py (GPIO)      │
                                     │  live_engine (ARM64) │
                                     └──────────────────────┘
```

- **Frontend** corre en tu laptop WSL, apunta al backend en la Pi.
- **Backend + main.py + live_engine** corren en la Raspberry Pi.
- MongoDB puede estar en Atlas o local en la Pi.

---

## 1. Backend (FastAPI + MongoDB) — en la Raspberry Pi

```bash
# Clonar/actualizar el repo en la Pi
cd ~/Proyecto1/backend
cp .env.example .env
nano .env   # configurar MONGODB_URI, etc.
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**Verificar:** `curl http://<PI_IP>:8000/api/health`

```json
{"status":"ok","mongodb":true,"mqtt_connected":true}
```

---

## 2. Frontend (React + Vite) — en tu laptop WSL

```bash
cd Proyecto1/frontend
pnpm install
pnpm dev
```

**Abrir:** `http://localhost:5173`

**Requiere:** El backend corriendo en la Pi. Si la IP de la Pi es `192.168.0.15`,  
configurar `VITE_API_URL=http://192.168.0.15:8000` en `frontend/.env`.

---

## 3. ARM64 — compilar (una vez, en la Pi)

```bash
cd ~/Proyecto1/arm64
make all
```

**Requiere:** `aarch64-linux-gnu-as` y `qemu-aarch64` instalados en la Pi.

---

## 4. Flujo ARM64 en vivo (Fase 2, RECOMENDADO)

**ARM64 decide, Python coordina, backend persiste.**

### Pipeline

```
Pi (GPIO: DHT22 + ADS1115)
  → orquestador.py --mode realtime
  → stdin → live_engine ARM64
  → stdout → ACTION/TARGET/RISK/REASON/VALUE/INDICATOR/STATUS
  → orquestador ejecuta GPIO (bomba, ventilador, luces, buzzer)
  → POST /api/arm64-results a backend local → MongoDB
```

### Correr en la Pi (loop infinito)

```bash
cd ~/Proyecto1/arm64/fase2/live_engine
python3 orquestador.py --mode realtime --interval 3 --api-url http://localhost:8000
```

### En tu laptop, abrir el frontend

```bash
cd Proyecto1/frontend
pnpm dev
# Abrir http://localhost:5173
```

### Probar sin Pi (simulado en laptop)

```bash
cd Proyecto1/arm64/fase2/live_engine
# Requiere qemu-aarch64 o correrlo en la misma maquina
python3 orquestador.py --once --no-gpio --no-mongo
```

Usa 13 lecturas de prueba predefinidas, imprime decisiones en consola.

### Modos del orquestador

| Modo | Comando | Uso |
|------|---------|-----|
| test | `orquestador.py` | 13 casos de prueba (default) |
| realtime | `orquestador.py --mode realtime` | GPIO real en la Pi |
| file | `orquestador.py --mode file --file data.csv` | Desde archivo CSV |

### Parametros adicionales

| Flag | Default | Descripcion |
|------|---------|-------------|
| `--interval` | 2s | Segundos entre lecturas |
| `--api-url` | `http://localhost:8000` | URL del backend |
| `--no-gpio` | off | Deshabilita GPIO (simulado) |
| `--no-mongo` | off | No registrar en MongoDB |
| `--once` | off | Una sola iteracion, luego sale |

### Verificar wiring

Ver `raspberry/wiring.md` para diagrama de pines GPIO.

---

## 5. Analisis historico ARM64

### Generar lecturas.csv desde MongoDB

```bash
cd ~/Proyecto1/backend
source .venv/bin/activate
python3 generate_lecturas.py --from-db
```

### Ejecutar modulo individual (via QEMU o nativo)

```bash
cd ~/Proyecto1/arm64/fase2
# RMSE: archivo inicio fin columna ideal
./build/rmse lecturas.csv 1 30 1 55
# Regresion lineal
./build/varianza lecturas.csv 1 30 1
# Prediccion
./build/prediccion lecturas.csv 1 30 1
# Integral del error
./build/integrals lecturas.csv 1 30 1 55
# Derivada local
./build/derivada lecturas.csv 1 30 1
```

### Enviar resultados al backend

```bash
cd ~/Proyecto1/raspberry
source ../backend/.venv/bin/activate
python3 arm_executor.py --parse-only --dir ../arm64 --url http://localhost:8000
```

---

## 6. Pruebas con MQTTX Web

```bash
# Broker: broker.emqx.io:8884 (WSS)
# Suscribir: grupo17/invernadero/#
# Publicar:
```
```json
{
  "sensor_type": "temperatura",
  "value": 34,
  "unit": "°C",
  "source": "mqttx_web"
}
```

**Flujo:** MQTTX → Broker → Backend → MongoDB → Dashboard

---

## 7. Raspberry Pi — main.py (lectura sensores legacy)

> main.py publica sensores a MQTT y maneja LCD/botones.  
> NO toma decisiones automaticas — eso lo hace ARM64.

```bash
cd ~/Proyecto1/raspberry
cp .env.example .env
nano .env   # ENABLE_GPIO=true, ajustar BACKEND_URL
pip install -r requirements.txt
python3 main.py
```

---

## 8. Limpieza de datos

```bash
cd ~/Proyecto1/backend
source .venv/bin/activate
python3 -c "
from pymongo import MongoClient
db = MongoClient('mongodb://localhost:27017').invernadero_iot
db.sensor_readings.delete_many({})
db.system_status.delete_many({})
db.events.delete_many({})
db.commands.delete_many({})
db.actuator_logs.delete_many({})
db.arm64_results.delete_many({})
print('Base de datos limpiada')
"
```

---

## Resumen de puertos

| Servicio | Puerto | Corre en |
|---|---|---|
| Backend (FastAPI) | `8000` | Raspberry Pi |
| Frontend (Vite) | `5173` | Laptop (WSL) |
| MongoDB | `27017` | Pi o Atlas |
| MQTT (HiveMQ) | `1883` (TCP) / `8884` (WSS) | Broker externo |
