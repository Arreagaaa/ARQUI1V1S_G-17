# ESTADO — Invernadero Inteligente IoT

**Última actualización:** 2026-06-05 — Limpieza post-fase MQTT; Módulo 1 ARM64 listo para QEMU.

---

## 1. Resumen ejecutivo

| Hito | Estado | Notas |
|---|---|---|
| Dashboard web (panel, gráficos, controles, ARM64) | ✅ COMPLETO | No modificar sin coordinar |
| Backend FastAPI + reglas automáticas | ✅ COMPLETO | Modo auto/manual, umbrales, 18 endpoints |
| MongoDB local (6 colecciones + índices + seed) | ✅ COMPLETO | Migración a Atlas = solo cambiar URI |
| MQTT con broker público + MQTTX Web | ✅ COMPLETO | `broker.emqx.io:1883` y `:8084` WSS, prefijo `grupo17/invernadero/` |
| Validación E2E con MQTTX Web (sin scripts) | ✅ 7/7 OK | gas, lights, mode, irrigation, anti-loop, recovery |
| Estructura ARM64 + `lecturas.csv` (formato enunciado) | ✅ plantilla | `media.s` listo; 4 módulos pendientes |
| **Módulo 1 ARM64 (media ponderada)** | ✅ **LISTO** | `media.s` 100% auto-contenido, 5 subrutinas propias, listo para QEMU |
| Módulos 2-5 ARM64 | ⏳ pendiente | README con instrucciones del enunciado; cada integrante crea su `.s` |
| `utils.s` (biblioteca común) | ⏳ tarea grupal | módulo 1 no lo necesita (auto-contenido) |
| Raspberry Pi + GPIO real + maqueta | ⬜ PENDIENTE | Bloqueado por hardware |
| MongoDB Atlas | ⬜ SIGUIENTE HITO | Cambiar `MONGODB_URI` y validar |
| Video + informe técnico | ⬜ PENDIENTE | Entrega final |

---

## 2. Fase actual: pre-Atlas / pre-maqueta / ARM64-en-curso

El sistema funciona 100% end-to-end con MQTTX Web como reemplazo de la Pi. La fase MQTT está cerrada y verificada manualmente (7/7 escenarios). Los scripts `simulador.py`, `test_mqttx_simulator.py`, `test_regresion.py` y `start.bat` fueron eliminados (commit `697a99d`); el sistema se arranca con `uvicorn` directo + `npm run dev` en terminales separadas.

### Cómo se ve el flujo hoy

```
MQTTX Web    ──► broker.emqx.io:8084 WSS ──► backend (suscrito)  ──► MongoDB
                                                                       └──► dashboard (polling 15s)
```

Cuando llegue la maqueta, el flujo será idéntico pero con `raspberry/main.py` reemplazando al cliente MQTTX.

### Lo que NO se debe tocar

- `frontend/src/` — dashboard está validado con usuarios
- `backend/app/routers/` y `backend/app/services/` — reglas y serialización probadas
- `backend/app/mqtt/connection_manager.py` — singleton MQTT; reload rompe la conexión
- `Proyecto1/arm64/modules/modulo_1_media/media.s` — listo y verificado contra enunciado §9.3 + repo del auxiliar

---

## 3. Roles y pendientes individuales

### Grupal (común)

| Tarea | Puntos | Estado | Acción inmediata |
|---|---|---|---|
| `arm64/utils/utils.s` (atoi, itoa, read CSV, write TXT) | 5 pts | ⏳ pendiente | Opcional para M1 (auto-contenido); recomendado para M2-M5 |
| Maqueta física (2 áreas + centro de control) | 100% grupal si falta | ⬜ | Bloqueado por hardware |
| Migración a MongoDB Atlas | 1-2 pts | ⬜ | Cambiar `MONGODB_URI` y verificar |
| Video + diagramas finales | obligatorio | ⬜ | Al final |

### Individual (5 módulos ARM64, 4 pts c/u)

| # | Módulo | Archivo | Estado | Fórmula | Salida |
|---|---|---|---|---|---|
| 1 | Media aritmética ponderada | `arm64/modules/modulo_1_media/media.s` | ✅ **LISTO** | `Σ(X_i·W_i) / ΣW_i` | `results/resultado_media.txt` |
| 2 | Varianza y desviación estándar | `arm64/modules/modulo_2_varianza/.s` (crear) | ⏳ pendiente | `VAR = Σ(X_i-μ)² / N`, `DESV = √VAR` | `results/resultado_varianza.txt` |
| 3 | Detección de anomalías estadísticas | `arm64/modules/modulo_3_anomalias/.s` (crear) | ⏳ pendiente | `Z = (X_i - μ) / σ` | `results/resultado_anomalias.txt` |
| 4 | Predicción lineal simple | `arm64/modules/modulo_4_prediccion/.s` (crear) | ⏳ pendiente | `PRED = X_n + (X_n - X_1) / (N-1)` | `results/resultado_prediccion.txt` |
| 5 | Tendencia acumulada avanzada | `arm64/modules/modulo_5_tendencia/.s` (crear) | ⏳ pendiente | `DIF_ACUM = Σ(X_i - X_{i-1})` | `results/resultado_tendencia.txt` |

**Cómo cada integrante (2-5) crea su módulo**:
1. Crear el archivo `.s` en su carpeta. El `README.md` de cada carpeta tiene las instrucciones exactas del enunciado §10.X.
2. Usar `media.s` como referencia funcional (mismo patrón: prólogo/epílogo, syscalls `openat`/`read`/`write`/`close`, ≥1 subrutina propia).
3. Actualizar el `Makefile`: cambiar el target `modulo2` (o el que corresponda) de `@false` a la regla de compilación real (ver `modulo1` como plantilla, líneas 90-100).
4. Compilar con `make moduloN`, ejecutar con `make runN`, depurar con `make gdbN`.

Requisitos por módulo (enunciado §9.3 + §13):
1. Compilar con `as -o modulo.o modulo.s && ld -o modulo modulo.o` (ARM64 nativo en la Pi).
2. Leer `lecturas.csv` (30 filas, 6 sensores) sin recalcular en Python.
3. Escribir `results/resultado_<nombre>.txt` con el formato exacto del enunciado §10.X.
4. Evidencia GDB (breakpoints, `info registers`, capturas).
5. Rama `feature/arm-integrante-<N>`, PR a `main`, revisión por otro integrante.
6. ≥1 subrutina propia (módulo 1 tiene 5 como referencia: `weighted_mean` es la principal; `parse_csv_column`, `sum_values`, `int_to_ascii`, `copy_str` son auxiliares).

Estructura ARM64:
```
arm64/
├── Makefile              # `all` compila utils + modulo1; targets 2-5 emiten "PENDIENTE"
├── lecturas.csv          # 30 lecturas (formato exacto del enunciado)
├── utils/
│   └── utils.s           # ⏳ Biblioteca común (TODO grupal; módulo 1 no lo usa)
├── modules/
│   ├── modulo_1_media/   # ✅ media.s listo + README con valores esperados
│   ├── modulo_2_varianza/  # ⏳ README con §10.2
│   ├── modulo_3_anomalias/ # ⏳ README con §10.3
│   ├── modulo_4_prediccion/ # ⏳ README con §10.4
│   └── modulo_5_tendencia/  # ⏳ README con §10.5
└── results/              # Salidas .txt de cada módulo
```

### Integración ARM64 ↔ IoT (10 pts)

| Tarea | Estado |
|---|---|
| Endpoints REST + colección `arm64_results` + dashboard | ✅ listo |
| `lecturas.csv` desde 30 lecturas **reales** del invernadero | ⬜ |
| `raspberry/arm_executor.py` (subprocess, sin calcular en Python) | ⬜ |
| GDB por integrante | ⬜ (M1 pendiente de probar en Ubuntu) |

---

## 4. Próximos pasos en orden

1. **Probar Módulo 1 ARM64 en Ubuntu** (Inmediato, en PC del integrante 1)
   - `sudo apt install binutils-aarch64-linux-gnu qemu-user`
   - `cd Proyecto1/arm64 && make run1`
   - Verificar `cat results/resultado_media.txt` → `SUM_X=892`, `WEIGHTED_MEAN=30`
   - Depurar con `make gdb1` (terminal 1) + `gdb-multiarch` (terminal 2)
   - Capturar evidencia para defensa individual
2. **MongoDB Atlas** (siguiente hito)
   - Crear cluster gratuito M0 en cloud.mongodb.com
   - Crear usuario de DB y agregar IP `0.0.0.0/0` (temporal) o la IP de la Pi
   - Copiar connection string → `MONGODB_URI` en `Proyecto1/backend/.env`
   - Reiniciar backend → validar `GET /api/health` → `mongodb: true`
3. **ARM64 `utils.s`** (tarea grupal, opcional para M1)
   - Funciones: `read_csv_line`, `atoi`, `itoa`, `write_result`
   - Módulo 1 es auto-contenido; los demás pueden esperar a `utils.s` o seguir el patrón de M1
4. **Módulos 2-5 `.s`** (uno por integrante, en paralelo)
   - Cada uno crea su `.s` siguiendo el patrón de `media.s` (5 subrutinas de referencia)
   - Actualizar `Makefile` cambiando el target `modulo2`-`modulo5` de `@false` a la regla real
   - Compilar con `make moduloN`, ejecutar con `make runN`, probar con `make gdbN`
5. **`raspberry/arm_executor.py`** (integración)
   - `subprocess.run(["./arm64/build/modulo_X"])` y parsear `resultado_X.txt`
   - `POST /api/arm64-results` con `source: raspi-01`
6. **Maqueta + GPIO** (cuando se tenga hardware)
   - 2 áreas de cultivo, 1 centro de control
   - DHT22, 2 higrómetros, LDR, MQ, **1 sola bomba + 2 válvulas selectoras** (Área 1/Área 2), ventilador, LEDs, buzzer, LCD, botones
7. **Video + diagramas finales**

---

## 5. Cómo re-validar antes de cada entrega

```bash
# 1. Levantar MongoDB local (Compass) y backend (PowerShell Windows)
cd Proyecto1\backend
C:\Users\crjav\AppData\Local\Programs\Python\Python313\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8080 --no-access-log

# 2. En otra terminal — frontend
cd Proyecto1\frontend && npm run dev
```

Validar manualmente con MQTTX Web (ver `Proyecto1/backend/BACKEND.md` §MQTTX Web — Guía paso a paso): suscribirse a `grupo17/invernadero/#`, publicar en `grupo17/invernadero/control/remoto` con `source: mqttx_<inicial>` y ver el cambio en el dashboard en ≤15s.

Para validar ARM64 módulo 1:
```bash
# En Ubuntu con toolchain
cd Proyecto1/arm64
make run1
cat results/resultado_media.txt
# Debe mostrar: MODULE=WEIGHTED_MEAN ... SUM_X=892 ... WEIGHTED_MEAN=30
```

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
