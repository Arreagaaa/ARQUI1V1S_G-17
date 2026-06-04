# ESTADO — Invernadero Inteligente IoT

**Última actualización:** 2026-06-04 — Fase MQTT cerrada, pre-Atlas / pre-maqueta / pre-ARM64.

---

## 1. Resumen ejecutivo

| Hito | Estado | Notas |
|---|---|---|
| Dashboard web (panel, gráficos, controles, ARM64) | ✅ COMPLETO | No modificar sin coordinar |
| Backend FastAPI + reglas automáticas | ✅ COMPLETO | Modo auto/manual, umbrales, 18 endpoints |
| MongoDB local (6 colecciones + índices + seed) | ✅ COMPLETO | Migración a Atlas = solo cambiar URI |
| MQTT con broker público + MQTTX Web | ✅ COMPLETO | `broker.emqx.io:1883` y `:8084` WSS |
| Suite de validación | ✅ COMPLETO | `test_regresion.py` 45/45, `test_mqttx_simulator.py` 12/12 |
| Estructura ARM64 + `lecturas.csv` (formato enunciado) | ✅ plantilla | Falta `utils.s` + 5 módulos `.s` por integrante |
| Raspberry Pi + GPIO real + maqueta | ⬜ PENDIENTE | Bloqueado por hardware |
| MongoDB Atlas | ⬜ SIGUIENTE HITO | Cambiar `MONGODB_URI` y validar |
| Módulos ARM64 compilables + GDB | ⬜ PENDIENTE | Responsabilidad individual |
| Video + informe técnico | ⬜ PENDIENTE | Entrega final |

---

## 2. Fase actual: pre-Atlas / pre-maqueta / pre-ARM

El sistema funciona 100% end-to-end con `simulador.py` y MQTTX Web como reemplazo de la Pi. La fase MQTT está cerrada y verificada con dos suites de tests.

### Cómo se ve el flujo hoy

```
simulador.py  ──► broker.emqx.io:1883  ──► backend (suscrito)  ──► MongoDB
                                                              └──► /api/dashboard
MQTTX Web    ──► broker.emqx.io:8084 WSS ──► backend (suscrito)  ──► MongoDB
                                                                      └──► dashboard (polling 15s)
```

Cuando llegue la maqueta, el flujo será idéntico pero con `raspberry/main.py` reemplazando al simulador.

### Lo que NO se debe tocar

- `frontend/src/` — dashboard está validado con usuarios
- `backend/app/routers/` y `backend/app/services/` — reglas y serialización probadas
- `backend/app/mqtt/connection_manager.py` — singleton MQTT; reload rompe la conexión

---

## 3. Roles y pendientes individuales

### Grupal (común)

| Tarea | Puntos | Estado | Acción inmediata |
|---|---|---|---|
| `arm64/utils/utils.s` (atoi, itoa, read CSV, write TXT) | 5 pts | ⬜ | Primero en hacer — desbloquea los 5 módulos |
| Makefile que compila y enlaza los 5 módulos | — | ⬜ | Después de `utils.s` |
| Maqueta física (2 áreas + centro de control) | 100% grupal si falta | ⬜ | Bloqueado por hardware |
| Migración a MongoDB Atlas | 1-2 pts | ⬜ | Cambiar `MONGODB_URI` y verificar |
| Video + diagramas finales | obligatorio | ⬜ | Al final |

### Individual (5 módulos ARM64, 4 pts c/u)

| # | Módulo | Archivo | Fórmula | Salida |
|---|---|---|---|---|
| 1 | Media aritmética ponderada | `arm64/modules/modulo_1_media/media.s` | `Σ(X_i·W_i) / ΣW_i` | `results/resultado_media.txt` |
| 2 | Varianza y desviación estándar | `arm64/modules/modulo_2_varianza/varianza.s` | `VAR = Σ(X_i-μ)² / N`, `DESV = √VAR` | `results/resultado_varianza.txt` |
| 3 | Detección de anomalías estadísticas | `arm64/modules/modulo_3_anomalias/anomalias.s` | `Z = (X_i - μ) / σ` | `results/resultado_anomalias.txt` |
| 4 | Predicción lineal simple | `arm64/modules/modulo_4_prediccion/prediccion.s` | `PRED = X_n + (X_n - X_1) / (N-1)` | `results/resultado_prediccion.txt` |
| 5 | Tendencia acumulada avanzada | `arm64/modules/modulo_5_tendencia/tendencia.s` | `DIF_ACUM = Σ(X_i - X_{i-1})` | `results/resultado_tendencia.txt` |

Requisitos por módulo:
1. Compilar con `as -o modulo.o modulo.s && ld -o modulo modulo.o` (ARM64 nativo en la Pi).
2. Leer `lecturas.csv` (30 filas, 6 sensores) sin recalcular en Python.
3. Escribir `results/resultado_<nombre>.txt`.
4. Evidencia GDB (breakpoints, `info registers`, capturas).
5. Rama `feature/arm-integrante-<N>`, PR a `main`, revisión por otro integrante.

Estructura ARM64:
```
arm64/
├── lecturas.csv            # 30 lecturas (formato exacto del enunciado)
├── utils/                  # utils.s compartido (5 pts — grupal, primero)
├── modules/                # 5 módulos, uno por integrante
│   ├── modulo_1_media/
│   ├── modulo_2_varianza/
│   ├── modulo_3_anomalias/
│   ├── modulo_4_prediccion/
│   └── modulo_5_tendencia/
└── results/                # Salidas .txt de cada módulo
```

### Integración ARM64 ↔ IoT (10 pts)

| Tarea | Estado |
|---|---|
| Endpoints REST + colección `arm64_results` + dashboard | ✅ listo |
| `lecturas.csv` desde 30 lecturas **reales** del invernadero | ⬜ |
| `raspberry/arm_executor.py` (subprocess, sin calcular en Python) | ⬜ |
| GDB por integrante | ⬜ |

---

## 4. Próximos pasos en orden

1. **MongoDB Atlas** (próximo hito)
   - Crear cluster gratuito M0 en cloud.mongodb.com
   - Crear usuario de DB y agregar IP `0.0.0.0/0` (temporal) o la IP de la Pi
   - Copiar connection string → `MONGODB_URI` en `Proyecto1/backend/.env`
   - Reiniciar backend → validar `GET /api/health` → `mongodb: true`
2. **ARM64 `utils.s`** (desbloquea los 5 módulos)
   - Funciones: `read_csv_line`, `atoi`, `itoa`, `write_result`
   - Compilar y probar con un módulo dummy antes de repartir
3. **5 módulos `.s`** (uno por integrante, en paralelo)
   - Usar `arm64/lecturas.csv` como input
   - Probar con `gdb ./moduleX` y capturar evidencia
4. **`raspberry/arm_executor.py`** (integración)
   - `subprocess.run(["./arm64/moduleX"])` y parsear `resultado_mX.txt`
   - `POST /api/arm64-results` con `source: raspi-01`
5. **Maqueta + GPIO** (cuando se tenga hardware)
   - 2 áreas de cultivo, 1 centro de control
   - DHT22, 2 higrómetros, LDR, MQ, bomba, ventilador, LEDs, buzzer, LCD, botones
6. **Video + diagramas finales**

---

## 5. Cómo re-validar antes de cada entrega

```bash
# 1. Levantar MongoDB local (Compass) y backend
cd Proyecto1/backend
pip install -r requirements.txt
python -m uvicorn app.main:app --host 127.0.0.1 --port 8080

# 2. En otra terminal
cd Proyecto1/backend
python test_regresion.py        # esperado: 45 OK, 0 FAIL
python test_mqttx_simulator.py  # esperado: 12/12 publicados
python simulador.py --once      # 6 lecturas al broker
```

Validar manualmente con MQTTX Web (ver `Proyecto1/docs/MQTTX_SETUP.md`): suscribirse a `grupo17/invernadero/#`, publicar en `grupo17/invernadero/control/remoto` con `source: mqttx_<inicial>` y ver el cambio en el dashboard en ≤15s.

---

## 6. Flujo Git

```bash
git checkout -b feature/arm-integrante-<N>   # NUNCA trabajar directo en main
git add <archivos>
git commit -m "feat(arm64): módulo X - <descripción>"
git push origin feature/arm-integrante-<N>
# Abrir PR en GitHub → asignar reviewer → merge a main
```

Convención de commits:
```
feat(arm64): ...    → nueva funcionalidad ARM64
feat(rasp): ...     → algo de la Raspberry
fix(backend): ...   → corrección backend
docs: ...           → documentación
```

---

## 7. Penalizaciones (del enunciado)

| Situación | Penalización |
|---|---|
| No presentar módulo ARM64 individual | 0 pts módulo + hasta **-50%** individual |
| Módulo no compila | 0 pts + hasta **-25%** individual |
| Compila pero no ejecuta | 0 pts + hasta **-10%** individual |
| No puede explicar su código ARM64 | 0 pts + hasta **-70%** individual |
| No puede defender cambios simples | hasta **-50%** individual |
| Python calcula lo que debe hacer ARM64 | 0 pts ARM64 + 0 pts integración + hasta **-40%** |
| Un integrante hace el módulo de otro | -60% al que no lo hizo, -50% al que lo hizo |
| No presentar maqueta física | **100% penalización grupal** |
| No presentar documentación técnica | **-15%** nota final |

---

## 8. Recursos

- Repositorio hermano: `D:\Projects\USAC\ARQUI1_1S2026\`
  - `01_PYTHON` — paho-mqtt, pymongo, sensores, MQTTX
  - `02_ARM64` — AArch64 assembly, arreglos, loops, ABI, GDB
  - `03_RISCV` — fase futura
- Repositorio del auxiliar: `PoncheDeFrutas`
- Documentación interna: `Proyecto1/docs/`
