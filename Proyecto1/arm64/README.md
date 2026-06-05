# Procesamiento ARM64 — Invernadero Inteligente IoT

**Rúbrica:** 25 pts (módulos) + 10 pts (integración) = **35 pts** del enunciado ACYE1.

---

## Estructura

```
arm64/
├── README.md                            # Este archivo
├── Makefile                             # Compila utils + 5 módulos con as/ld
├── lecturas.csv                         # 30 lecturas reales (header + 30 + $)
├── utils/
│   └── utils.s                          # Biblioteca común (TODO: implementar)
├── modules/
│   ├── modulo_1_media/
│   │   ├── media.s                      # Media aritmética ponderada (Integrante 1)
│   │   └── README.md                    # Fórmula, columna, salida, GDB
│   ├── modulo_2_varianza/
│   │   ├── varianza.s                   # Varianza y desv. estándar (Integrante 2)
│   │   └── README.md
│   ├── modulo_3_anomalias/
│   │   ├── anomalias.s                  # Detección estadística (Integrante 3)
│   │   └── README.md
│   ├── modulo_4_prediccion/
│   │   ├── prediccion.s                 # Predicción lineal simple (Integrante 4)
│   │   └── README.md
│   └── modulo_5_tendencia/
│       ├── tendencia.s                  # Tendencia acumulada avanzada (Integrante 5)
│       └── README.md
└── results/
    └── .gitkeep                         # Carpeta donde se escriben los resultado_*.txt
```

---

## Flujo obligatorio de integración (enunciado §9.1)

```
Sensores reales → Python → lecturas.csv → Módulos ARM64 → resultados_arm64/ → Python → MongoDB → Dashboard
```

> ⚠️ **Python NO podrá realizar los cálculos solicitados a las rutinas de ARM64** (enunciado §13, restricción 1). Esto es PENALIZADO con 0 pts + hasta -40% si se viola.

---

## Compilación

### En Raspberry Pi 3/4 (nativa)

```bash
# Toolchain nativa (ya incluida en Raspberry Pi OS 64-bit)
make all            # compila utils + los 5 módulos
./build/modulo_1_media
cat results/resultado_media.txt
```

### En PC con QEMU (para pruebas cruzadas)

```bash
sudo apt install binutils-aarch64-linux-gnu qemu-user gdb-multiarch
make all
make run1           # ejecuta modulo_1_media con qemu-aarch64
```

### Targets individuales del Makefile

| Target | Descripción |
|---|---|
| `make utils` | Solo `utils.o` |
| `make modulo1` | Solo módulo 1 (media) |
| `make modulo2` | Solo módulo 2 (varianza) |
| `make modulo3` | Solo módulo 3 (anomalías) |
| `make modulo4` | Solo módulo 4 (predicción) |
| `make modulo5` | Solo módulo 5 (tendencia) |
| `make all` | Todo |
| `make run1` ... `run5` | Ejecuta el módulo N con QEMU |
| `make gdb1` ... `gdb5` | Inicia servidor QEMU en :1234 para GDB |
| `make clean` | Borra `build/` |
| `make info` | Muestra toolchain y rutas |

---

## Depuración con GDB

### Raspberry Pi (nativo)

```bash
gdb ./build/modulo_1_media
(gdb) set architecture aarch64
(gdb) break _start
(gdb) run
(gdb) info registers
```

### PC con QEMU

**Terminal 1** (servidor QEMU en :1234):
```bash
make gdb1
```

**Terminal 2** (cliente GDB):
```bash
gdb-multiarch build/modulo_1_media
(gdb) set architecture aarch64
(gdb) target remote :1234
(gdb) break _start
(gdb) continue
```

---

## Formatos de salida (enunciado §10)

Los **5 módulos** deben escribir su `resultado_*.txt` con **exactamente** este formato (sin espacios alrededor del `=`, líneas en este orden, terminador `\n`):

| Módulo | Archivo | Variables |
|---|---|---|
| 1 | `results/resultado_media.txt` | `MODULE=WEIGHTED_MEAN` `TOTAL_VALUES=30` `SUM_X=920` `WEIGHT_SUM=465` `WEIGHTED_MEAN=31` |
| 2 | `results/resultado_varianza.txt` | `MODULE=VARIANCE` `TOTAL_VALUES=30` `MEAN=31` `VARIANCE=18` `STD_DEV=4` |
| 3 | `results/resultado_anomalias.txt` | `MODULE=ANOMALY_DETECTION` `TOTAL_VALUES=30` `MEAN=29` `STD_DEV=3` `ANOMALIES=4` `SYSTEM_RISK=HIGH` |
| 4 | `results/resultado_prediccion.txt` | `MODULE=PREDICTION` `INITIAL_VALUE=28` `FINAL_VALUE=34` `TOTAL_DIFF=6` `AVG_CHANGE=0.20` `NEXT_VALUE=34.20` |
| 5 | `results/resultado_tendencia.txt` | `MODULE=ADVANCED_TREND` `TOTAL_VALUES=30` `INCREMENTS=18` `DECREMENTS=10` `MAX_UP_STREAK=5` `MAX_DOWN_STREAK=3` `ACCUM_DIFF=7` `TREND=UP` |

> ⚠️ `AVG_CHANGE` y `NEXT_VALUE` del módulo 4 tienen **2 decimales**. Todo lo demás son enteros.

---

## Distribución de trabajo

| Módulo | Integrante | Subrutina(s) propia(s) mínima(s) |
|---|---|---|
| 1 — Media ponderada | 1 | `weighted_mean(values)` |
| 2 — Varianza | 2 | `compute_mean`, `compute_variance`, `isqrt` |
| 3 — Anomalías | 3 | `compute_mean`, `compute_std_dev`, `count_anomalies`, `classify` |
| 4 — Predicción | 4 | `format_fixed_point` (punto fijo ×100) |
| 5 — Tendencia | 5 | `compute_tendency` |

**Grupal (1 sola persona o 2):** `utils.s` (la biblioteca común). Sin esto los 5 módulos no pueden compilar.

---

## Bibliografía (repo del auxiliar)

- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\` — ruta canónica 00..17
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\projects\src\` — `input.s`, `print.s`, `constants.inc`
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\tools\makefile-templates\` — 4 variantes de Makefile
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\.vscode\launch.json` — config VS Code + GDB
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\docs\02_debugging.md` — guía de depuración
