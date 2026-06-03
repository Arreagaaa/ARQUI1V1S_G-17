# 👨‍💻 Guía para Desarrolladores — Invernadero Inteligente

Este documento explica **qué debe hacer cada integrante** del Grupo 17 para completar el proyecto. Léanlo completo antes de empezar.

---

## 1. Configurar tu entorno local

### Clonar el repo y crear tu rama

```bash
# Clonar
git clone https://github.com/<org>/ARQUI1V1S_G-17.git
cd ARQUI1V1S_G-17/Proyecto1

# Crear tu rama de trabajo (NUNCA trabajar directo en main)
git checkout -b feature/arm-integrante-<N>
# Ejemplo: git checkout -b feature/arm-integrante-1
```

### Levantar el sistema localmente

```bash
# Backend
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp ../.env.example .env   # Editar si es necesario
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000

# Frontend (otra terminal)
cd frontend
pnpm install
pnpm dev
```

Verificar que todo funcione:
- Dashboard: `http://localhost:5173`
- API docs: `http://localhost:8000/docs`
- Health check: `curl http://localhost:8000/api/health` → debe retornar `"mongodb": true`

---

## 2. Lo que YA está hecho (NO tocar)

> ⚠️ **No modifiquen el frontend ni el backend** sin consultar primero. Ya están 100% funcionales.

| Componente | Estado |
|---|---|
| Backend FastAPI (todos los endpoints) | ✅ Listo |
| Frontend React (dashboard, gráficos, controles) | ✅ Listo |
| MongoDB local (todas las colecciones) | ✅ Listo |
| Validación de rangos de sensores | ✅ Listo |
| Reglas automáticas (gas, temp, suelo) | ✅ Listo |
| Serialización ObjectId → string | ✅ Listo |
| Endpoint ARM64 results (GET/POST + mock) | ✅ Listo |
| Contrato MQTT documentado | ✅ Listo |

---

## 3. Lo que falta: ARM64 (cada integrante)

Según el enunciado, el proyecto tiene **5 módulos ARM64**, uno por integrante. Cada módulo vale **4 puntos** y la biblioteca común `utils.s` vale **5 puntos**.

### 3.1 Biblioteca común: `utils.s` (5 pts)

Crear el archivo `arm64/utils.s` con las siguientes funciones compartidas:
- Lectura de `lecturas.csv` línea por línea
- Parsing de campos separados por coma
- Conversión ASCII → entero (atoi)
- Conversión entero → ASCII (itoa) para escritura
- Escritura de resultados a archivo `.txt`

### 3.2 Módulos individuales

| # | Módulo | Responsable | Archivo | Entrada | Salida |
|---|---|---|---|---|---|
| 1 | **Media aritmética ponderada** | Integrante 1 | `arm64/module1_weighted_mean.s` | `lecturas.csv` | `resultado_m1.txt` |
| 2 | **Varianza y desviación estándar** | Integrante 2 | `arm64/module2_variance.s` | `lecturas.csv` | `resultado_m2.txt` |
| 3 | **Detección estadística de anomalías** | Integrante 3 | `arm64/module3_anomaly.s` | `lecturas.csv` | `resultado_m3.txt` |
| 4 | **Predicción lineal simple** | Integrante 4 | `arm64/module4_prediction.s` | `lecturas.csv` | `resultado_m4.txt` |
| 5 | **Tendencia acumulada avanzada** | Integrante 5 | `arm64/module5_trend.s` | `lecturas.csv` | `resultado_m5.txt` |

### 3.3 Requisitos de CADA módulo

1. **Compilar** con `as` y `ld` (ARM64 nativo en la Pi):
   ```bash
   as -o moduleX.o moduleX.s
   ld -o moduleX moduleX.o
   ```
2. **Leer** `lecturas.csv` (30 filas de datos reales del invernadero).
3. **Procesar** los datos según el algoritmo asignado.
4. **Escribir** resultado en `resultado_mX.txt`.
5. **Depuración con GDB**: cada integrante debe mostrar evidencia de depuración con GDB (breakpoints, registros, memoria).

### 3.4 Formato de `lecturas.csv`

El archivo es generado por Python desde lecturas reales del invernadero. Formato:

```csv
timestamp,sensor_type,value,area
2026-06-03T10:00:00,temperature,28.5,area_1
2026-06-03T10:00:00,temperature,29.1,area_2
2026-06-03T10:01:00,temperature,28.8,area_1
...
```

---

## 4. Integración ARM64 ↔ Sistema IoT (10 pts)

Una vez que los módulos compilen y funcionen, hay que integrarlos al sistema:

### 4.1 Generar `lecturas.csv` desde Python (2 pts)

Crear `raspberry/generate_csv.py` que:
1. Consulte las últimas 30 lecturas desde MongoDB (o las lea del sensor en vivo).
2. Las guarde en formato CSV en `arm64/lecturas.csv`.

### 4.2 Ejecutar módulos ARM64 desde Python (2 pts)

Crear `raspberry/arm_executor.py` que:
1. Ejecute cada binario ARM64 con `subprocess.run()`.
2. Capture stdout o lea el archivo de salida.

```python
import subprocess

modules = [
    ("WEIGHTED_MEAN", "./arm64/module1"),
    ("VARIANCE", "./arm64/module2"),
    ("ANOMALY_DETECTION", "./arm64/module3"),
    ("PREDICTION", "./arm64/module4"),
    ("ADVANCED_TREND", "./arm64/module5"),
]

for name, binary in modules:
    result = subprocess.run([binary], capture_output=True, text=True)
    # Leer resultado_mX.txt y enviarlo al backend
```

### 4.3 Almacenar resultados en MongoDB (2 pts)

Usar el endpoint `POST /api/arm64-results` con payload:

```json
{
  "module": "WEIGHTED_MEAN",
  "total_values": 30,
  "results": {
    "SUM_X": 920,
    "WEIGHT_SUM": 465,
    "WEIGHTED_MEAN": 31
  },
  "source": "raspi-01"
}
```

### 4.4 Visualización en dashboard (1 pt)

El dashboard YA tiene la sección de ARM64 Results. Solo necesitan enviar datos reales.

### 4.5 Evidencia de depuración GDB (1 pt)

Cada integrante debe:
1. Abrir su módulo con `gdb ./moduleX`
2. Poner breakpoints en puntos clave
3. Inspeccionar registros (`info registers`)
4. Tomar captura de pantalla como evidencia

---

## 5. Flujo Git para entregar

```bash
# 1. Asegurarte que estás en tu rama
git checkout feature/arm-integrante-<N>

# 2. Agregar tus archivos
git add arm64/moduleX.s arm64/resultado_mX.txt

# 3. Commit con mensaje descriptivo
git commit -m "feat(arm64): módulo X - media aritmética ponderada"

# 4. Push a GitHub
git push origin feature/arm-integrante-<N>

# 5. Abrir Pull Request en GitHub hacia main
#    - Título: "ARM64 Módulo X: <descripción>"
#    - Asignar reviewer (otro integrante)

# 6. Después de aprobación, merge a main
```

### Convenciones de commits

```
feat(arm64): descripción     → Nueva funcionalidad ARM64
feat(rasp): descripción      → Algo de la Raspberry
fix(backend): descripción    → Corrección en el backend
docs: descripción            → Cambios en documentación
```

---

## 6. Penalizaciones importantes (del enunciado)

> ⚠️ Léanlas bien, perder puntos por estas cosas es innecesario.

| Situación | Penalización |
|---|---|
| No presentar módulo ARM64 individual | 0 pts en el módulo + **hasta -50%** nota individual |
| Módulo ARM64 no compila | 0 pts + hasta **-25%** nota individual |
| Compila pero no ejecuta correctamente | 0 pts + hasta **-10%** nota individual |
| No puede explicar su código ARM64 | 0 pts + hasta **-70%** nota individual |
| No puede defender cambios simples | Hasta **-50%** nota individual |
| Python hace cálculo que debía hacer ARM64 | 0 pts ARM64 + 0 pts integración + hasta **-40%** |
| Un integrante hace el módulo de otro | -60% al que no lo hizo, -50% al que lo hizo |
| No presentar maqueta física | **100% penalización grupal** |
| No presentar documentación técnica | **-15%** nota final |

---

## 7. Contacto y dudas

Si algo no funciona o no entienden algo del backend/frontend, **pregunten en el grupo** antes de modificar archivos que ya están listos. La web ya está terminada y probada.
