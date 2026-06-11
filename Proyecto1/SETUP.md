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

## 3. Simulador de Sensores (pruebas sin Raspberry Pi)

```bash
cd Proyecto1/backend
source .venv/bin/activate
python3 simulador.py --scenario ninguno
```

Publica lecturas cada 5 segundos por MQTT. Escenarios disponibles:

| Escenario | Efecto |
|---|---|
| `ninguno` | Valores aleatorios normales |
| `emergencia` | Gas alto (>700ppm) → EMERGENCIA |
| `seco_area_1` | Suelo área 1 seco (<15%) → RIEGO_ACTIVO |
| `saturado_area_2` | Suelo área 2 saturado (>85%) → apaga bomba |
| `poca_luz` | Luz <200 lux → POCA_LUZ |

**Salida esperada:**
```
Publicado: T=25.2°C H=53.5% S1=52.6% S2=42.6% L=50.7 lux G=78.4 ppm
```

---

## 4. ARM64 (módulos de análisis)

Los módulos ARM64 leen `arm64/lecturas.csv` (30 registros reales desde MongoDB).

### 1. Generar lecturas.csv desde MongoDB (opcional — actualizar datos)
```bash
cd Proyecto1/backend
source .venv/bin/activate
python3 generate_lecturas.py --from-db
```
Esto sobreescribe `arm64/lecturas.csv` con los últimos 30 registros de MongoDB.

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

### Todo en uno
```bash
cd Proyecto1/arm64 && make all && \
  cd ../raspberry && python3 arm_executor.py --parse-only --dir ../arm64 --url http://localhost:8000
```

**Requiere:** `aarch64-linux-gnu-as` y `qemu-aarch64` instalados.

---

## 5. Pruebas con MQTTX Web

1. Abrir [MQTTX Web](https://mqttx.app/web)
2. Conexión:
    - **Host:** `broker.emqx.io`
   - **Puerto:** `8884` (WSS)
   - **Client ID:** `mqttx-test-<random>`
3. Suscribir: `grupo17/invernadero/#`
4. Publicar un sensor (ejemplo):
   ```json
   {
     "sensor_type": "temperatura",
     "value": 34.0,
     "unit": "°C",
     "source": "mqttx_web"
   }
   ```
5. Ver el cambio en el dashboard web o en `grupo17/invernadero/estado/global`

**Flujo completo:** MQTTX → Broker → Backend → MongoDB → Dashboard

---

## 6. Raspberry Pi (física)

```bash
cd Proyecto1/raspberry
cp .env.example .env
nano .env   # ENABLE_GPIO=true, ajustar BACKEND_URL
pip install -r requirements.txt
python3 main.py
```

**Ver `wiring.md`** para el diagrama de conexión de pines GPIO y componentes.

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
