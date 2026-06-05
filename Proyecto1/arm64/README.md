# Procesamiento ARM64 — Invernadero Inteligente IoT

**Rúbrica:** 25 pts (módulos) + 10 pts (integración) = **35 pts** del enunciado ACYE1.

> **Estado (2026-06-05)**
> - ✅ **Módulo 1 — Media ponderada: LISTO** (Integrante 1 — `media.s` auto-contenido, compila con `as`/`ld`, ejecutable en QEMU)
> - ⏳ Módulo 2 — Varianza: pendiente (Integrante 2)
> - ⏳ Módulo 3 — Anomalías: pendiente (Integrante 3)
> - ⏳ Módulo 4 — Predicción: pendiente (Integrante 4)
> - ⏳ Módulo 5 — Tendencia: pendiente (Integrante 5)
> - ⏳ `utils.s` (biblioteca común) — tarea grupal pendiente
>
> Los 4 módulos pendientes tienen su `README.md` con las instrucciones exactas del enunciado §10.2 a §10.5.

---

## Estructura

```
arm64/
├── README.md                            # Este archivo
├── Makefile                             # Compila utils + módulos; targets pendientes emiten mensaje
├── lecturas.csv                         # 30 lecturas reales (header + 30 + $)
├── utils/
│   └── utils.s                          # Biblioteca común (TAREA GRUPAL — TODO)
├── modules/
│   ├── modulo_1_media/
│   │   ├── media.s                      # ✅ Media aritmética ponderada (Integrante 1) — LISTO
│   │   └── README.md                    # Fórmula, columna, salida, GDB, valores esperados
│   ├── modulo_2_varianza/
│   │   └── README.md                    # ⏳ Instrucciones del enunciado §10.2 (Integrante 2)
│   ├── modulo_3_anomalias/
│   │   └── README.md                    # ⏳ Instrucciones del enunciado §10.3 (Integrante 3)
│   ├── modulo_4_prediccion/
│   │   └── README.md                    # ⏳ Instrucciones del enunciado §10.4 (Integrante 4)
│   └── modulo_5_tendencia/
│       └── README.md                    # ⏳ Instrucciones del enunciado §10.5 (Integrante 5)
└── results/
    └── .gitkeep                         # Carpeta donde se escriben los resultado_*.txt
```

---

## Flujo obligatorio de integración (enunciado §9.1)

```
Sensores reales → Python → lecturas.csv → Módulos ARM64 → results/ → Python → MongoDB → Dashboard
```

> ⚠️ **Python NO podrá realizar los cálculos solicitados a las rutinas de ARM64** (enunciado §13, restricción 1). Esto es PENALIZADO con 0 pts + hasta -40% si se viola.

---

## Compilación

### En Raspberry Pi 3/4 (nativa)

```bash
# Toolchain nativa (ya incluida en Raspberry Pi OS 64-bit)
make all            # compila utils + modulo_1_media (lo único listo)
./build/modulo_1_media
cat results/resultado_media.txt
# Esperado: MODULE=WEIGHTED_MEAN ... SUM_X=892 ... WEIGHTED_MEAN=30
```

### En PC con QEMU (para pruebas cruzadas)

```bash
sudo apt install binutils-aarch64-linux-gnu qemu-user gdb-multiarch
make all
make run1           # ejecuta modulo_1_media con qemu-aarch64
```

### Comandos clave

| Comando | Qué hace |
|---|---|
| `make all` | Compila `utils.o` + `modulo_1_media` |
| `make run1` | Compila y ejecuta módulo 1 con QEMU |
| `make gdb1` | Compila e inicia servidor QEMU en `:1234` para GDB |
| `make status` | Muestra qué módulos están implementados y cuáles pendientes |
| `make info` | Toolchain, rutas, módulos |
| `make clean` | Borra `build/` |
| `make modulo2` ... `modulo5` | Muestran mensaje "PENDIENTE" y salen con error (esperado) |

> **Nota sobre los targets pendientes**: `make modulo2` a `make modulo5` emiten un mensaje informativo y devuelven error (exit code 1) intencionalmente. Esto es para que un `make all` accidental no falle silencioso cuando falten los 4 archivos. Cuando cada integrante cree su `.s`, el target correspondiente se actualizará automáticamente.

---

## Depuración con GDB (módulo 1, ya listo)

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
(gdb) break weighted_mean
(gdb) info registers
(gdb) print $x22        # weighted_mean
(gdb) print $x21        # sum_x
```

> Ver `modules/modulo_1_media/README.md` para breakpoints sugeridos y comandos específicos.

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
>
> ⚠️ Los valores numéricos del enunciado son ejemplos — los reales dependen de `lecturas.csv`. El módulo 1 con el CSV actual produce `SUM_X=892` y `WEIGHTED_MEAN=30`.

---

## Distribución de trabajo

| Módulo | Integrante | Estado | Subrutina(s) propia(s) mínima(s) (enunciado §10) |
|---|---|---|---|
| 1 — Media ponderada | 1 | ✅ **LISTO** | `weighted_mean(values)` (módulo tiene 5 subrutinas: weighted_mean, sum_values, parse_csv_column, int_to_ascii, copy_str) |
| 2 — Varianza | 2 | ⏳ pendiente | `compute_mean`, `compute_variance`, `isqrt` |
| 3 — Anomalías | 3 | ⏳ pendiente | `compute_mean`, `compute_std_dev`, `count_anomalies`, `classify` |
| 4 — Predicción | 4 | ⏳ pendiente | `format_fixed_point` (punto fijo ×100) |
| 5 — Tendencia | 5 | ⏳ pendiente | `compute_tendency` |

**Grupal (1 o 2 personas):** `utils.s` (la biblioteca común). El módulo 1 es auto-contenido y funciona sin él; los otros 4 pueden seguir el mismo patrón o esperar a `utils.s`.

**Cómo cada integrante crea su módulo**:
1. Crear el archivo `.s` en su carpeta (`media.s` ya está como referencia funcional):
   ```
   modules/modulo_2_varianza/varianza.s
   modules/modulo_3_anomalias/anomalias.s
   modules/modulo_4_prediccion/prediccion.s
   modules/modulo_5_tendencia/tendencia.s
   ```
2. Implementar siguiendo el patrón de `media.s` (prólogo/epílogo, syscalls `openat`/`read`/`write`/`close`, ≥1 subrutina propia).
3. Actualizar el `Makefile` cambiando el target `modulo2` (o el que corresponda) de `@false` a la regla de compilación real (ver `modulo1` como plantilla).
4. Compilar con `make moduloN`, ejecutar con `make runN`, depurar con `make gdbN`.

---

## Bibliografía (repo del auxiliar)

- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\` — ruta canónica 00..17
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\projects\src\` — `input.s`, `print.s`, `constants.inc`
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\tools\makefile-templates\` — 4 variantes de Makefile
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\.vscode\launch.json` — config VS Code + GDB
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\docs\02_debugging.md` — guía de depuración
