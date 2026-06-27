# SETUP — Cómo correr todo el proyecto

## 1. Backend (FastAPI + MongoDB)

```bash
cd Proyecto1/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**Requiere:** MongoDB corriendo en `localhost:27017` (o configurar `MONGODB_URI` en `.env`).

**Verificar:** `curl http://localhost:8000/api/health`

```json
{"status":"ok","mongodb":true,"mqtt_connected":true}
```

---

## 2. Frontend (React + Vite)

```bash
cd Proyecto1/frontend
pnpm install
pnpm dev
```

**Abrir:** `http://localhost:5173`

**Requiere:** Backend corriendo en `http://localhost:8000`.

---

## 3. ARM64 (módulos de análisis históricos — Fase 1 legacy)

Los módulos ARM64 leen `arm64/lecturas.csv` (30 registros desde MongoDB).

### 1. Generar lecturas.csv desde MongoDB
```bash
cd Proyecto1/backend
source .venv/bin/activate
python3 generate_lecturas.py --from-db
```

### 2. Compilar
```bash
cd Proyecto1/arm64
make all
```

### 3. Ejecutar individualmente (vía QEMU)
```bash
make run1   # Media ponderada
make run2   # Varianza y desv. estándar
make run3   # Detección de anomalías
make run4   # Predicción lineal
make run5   # Tendencia acumulada
```

### 4. Enviar resultados al backend
```bash
cd Proyecto1/raspberry
source ../backend/.venv/bin/activate
python3 arm_executor.py --parse-only --dir ../arm64 --url http://localhost:8000
```

**Requiere:** `aarch64-linux-gnu-as` y `qemu-aarch64` instalados.

---

## 4. Raspberry Pi — Flujo ARM64 en vivo (Fase 2, RECOMENDADO)

**Este es el flujo principal de Fase 2.** ARM64 toma las decisiones,
Python solo coordina. El backend solo persiste datos.

### Pipeline

```
Pi (GPIO: DHT22 + ADS1115)
  → orquestador.py --mode realtime
  → stdin → live_engine ARM64 (AArch64)
  → stdout → ACTION / TARGET / RISK / REASON / VALUE / INDICATOR / STATUS
  → orquestador ejecuta GPIO (bomba, ventilador, luces, buzzer)
  → POST /api/arm64-results a backend → MongoDB → Dashboard
```

### Compilar motor ARM64 (una vez)
```bash
cd Proyecto1/arm64
make all
```
Esto compila `arm64/fase2/build/live_engine`.

### Correr en la Pi (loop infinito)
```bash
cd Proyecto1/arm64/fase2/live_engine
python3 orquestador.py --mode realtime --interval 3 --api-url http://<PC_BACKEND>:8000
```

### Probar sin Pi (simulado)
```bash
cd Proyecto1/arm64/fase2/live_engine
python3 orquestador.py --once --no-gpio --no-mongo
```
Usa 13 lecturas de prueba predefinidas, imprime decisiones en consola.

### Modos del orquestador
| Modo | Comando | Uso |
|------|---------|-----|
| test | `orquestador.py` | 13 casos de prueba (default) |
| realtime | `orquestador.py --mode realtime` | GPIO real en la Pi |
| file | `orquestador.py --mode file --file data.csv` | Desde archivo CSV |

### Parámetros adicionales
| Flag | Default | Descripción |
|------|---------|-------------|
| `--interval` | 2s | Segundos entre lecturas |
| `--api-url` | `http://localhost:8000` | URL del backend (IP del PC) |
| `--no-gpio` | off | Deshabilita GPIO (simulado) |
| `--no-mongo` | off | No registrar en MongoDB |
| `--once` | off | Una sola iteración, luego sale |

### Verificar wiring
Ver `raspberry/wiring.md` para diagrama de pines GPIO.


## 5. Pruebas con MQTTX Web

```bash
# Broker: broker.emqx.io:8884 (WSS)
# Suscribir: grupo17/invernadero/#
# Publicar:
```
```json
{
  "sensor_type": "temperatura",
  "value": 34.0,
  "unit": "°C",
  "source": "mqttx_web"
}
```

**Flujo:** MQTTX → Broker → Backend → MongoDB → Dashboard


## 6. Raspberry Pi — main.py legacy (Fase 1, OPCIONAL)

> ⚠️ `main.py` ya NO toma decisiones automáticas. Las reglas de
> automatización del backend (`_apply_automation_rules`) están
> desactivadas. Usar solo si se necesita publicar sensores a MQTT
> o manejar LCD/botones SIN interferir con ARM64.

```bash
cd Proyecto1/raspberry
cp .env.example .env
nano .env   # ENABLE_GPIO=true, ajustar BACKEND_URL
pip install -r requirements.txt
python3 main.py
```

---

## 7. Limpieza de datos

```bash
cd Proyecto1/backend
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

| Servicio | Puerto |
|---|---|
| Backend (FastAPI) | `8000` |
| Frontend (Vite) | `5173` |
| MongoDB | `27017` |
| MQTT (HiveMQ) | `1883` (TCP) / `8884` (WSS) |
