# Módulo 1 — Media Aritmética Ponderada

**Integrante 1** | Archivo: `media.s` | Salida: `../../results/resultado_media.txt`

---

## Fórmula matemática

```
MEDIA_PONDERADA = Σ(X_i * W_i) / ΣW_i
```

Donde:
- `X_i` = valor de la columna TEMP en la lectura `i` (i = 1..30)
- `W_i` = peso de la lectura `i` = `i` (1, 2, 3, …, 30)
- `ΣW_i` = 1 + 2 + 3 + … + 30 = 30 × 31 / 2 = **465**

---

## Columna del CSV que usa

- **Columna 1** del archivo `../../lecturas.csv` → `TEMP` (temperatura en °C)
- 30 lecturas exactas (líneas 2-31 del CSV)
- Línea 32 es el terminador `$` (no se procesa)

---

## Formato exacto de salida

El módulo debe escribir en `../../results/resultado_media.txt`:

```
MODULE=WEIGHTED_MEAN
TOTAL_VALUES=30
SUM_X=920
WEIGHT_SUM=465
WEIGHTED_MEAN=31
```

> ⚠️ **El enunciado es estricto**: cualquier desviación del formato (espacios, mayúsculas, orden de líneas) puede invalidar la rúbrica. Usar exactamente `MODULE=`, `TOTAL_VALUES=`, `SUM_X=`, `WEIGHT_SUM=`, `WEIGHTED_MEAN=`.

Los valores numéricos son de ejemplo (cambian con `lecturas.csv`); lo que importa es el formato.

---

## Algoritmo esperado

```
1. Abrir ../lecturas.csv
2. Leer 30 líneas, extraer columna 1 (TEMP) → arreglo values[30]
3. acc_weighted = 0
4. Para i = 0..29:
       weight = i + 1
       acc_weighted += values[i] * weight
5. mean = acc_weighted / 465        // división entera
6. sum_x = Σ values[i]              // requerido por el formato
7. Escribir 4 líneas en resultado_media.txt
8. exit(0)
```

### Sugerencia de registros (ABI AArch64)

| Registro | Uso |
|---|---|
| `x0` | puntero / retorno |
| `x9` | puntero base del arreglo `values` |
| `x10` | índice del loop (`i`) |
| `x11` | peso (`i + 1`) |
| `x12` | acumulador `acc_weighted` |
| `x13` | acumulador `sum_x` |
| `x19-x28` | callee-saved (preservar entre subrutinas) |

### Subrutinas externas necesarias (de `utils.s`)

```asm
.extern utils_open_csv
.extern utils_read_int_column
.extern utils_write_result
.extern utils_exit
.extern utils_print_string   // opcional, para debug
```

---

## Compilar y ejecutar en Raspberry Pi 3/4

```bash
# Desde el directorio arm64/
make utils        # compila utils/utils.s → build/utils.o
make modulo1      # compila y enlaza media.s → build/modulo_1_media
./build/modulo_1_media
cat results/resultado_media.txt
```

Salida esperada: las 4 líneas con los valores calculados a partir de `lecturas.csv`.

---

## Compilar y ejecutar en PC con QEMU (sin Pi)

```bash
sudo apt install qemu-user gdb-multiarch binutils-aarch64-linux-gnu
make run1         # ejecuta build/modulo_1_media bajo qemu-aarch64
```

---

## Depurar con GDB

### En Raspberry Pi (nativo)

```bash
gdb ./build/modulo_1_media
(gdb) set architecture aarch64
(gdb) break _start
(gdb) run
(gdb) info registers
(gdb) step / next / continue
```

### En PC con QEMU + GDB multi-arquitectura

**Terminal 1** (servidor QEMU en puerto 1234):
```bash
make gdb1
# equivalente a: qemu-aarch64 -g 1234 build/modulo_1_media
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
(gdb) print/x $x0
```

### Breakpoints sugeridos

| Punto | Comando |
|---|---|
| Inicio del programa | `break _start` |
| Entrada a la subrutina propia | `break weighted_mean` |
| Después del loop principal | `break _start+...` (línea de la división) |
| Antes del `svc` de exit | `break utils_exit` |

### Comandos útiles

| Acción | Comando |
|---|---|
| Ver registros | `info registers` |
| Ver un registro específico | `print $x12` |
| Ver memoria | `x/30gx $x9` (30 valores de 8 bytes del arreglo) |
| Avanzar paso a paso | `step` / `next` |
| Continuar | `continue` |
| Salir | `quit` |

---

## Evidencia para la defensa

Capturar:
1. `gdb> info registers` justo antes de `utils_exit` con valores finales
2. `cat results/resultado_media.txt` con el archivo generado
3. Captura de pantalla de la sesión GDB con breakpoints marcados
4. Commit individual con solo `media.s` y este README

---

## Referencias (repo auxiliar)

- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\10_stack_y_funciones` — prólogo/epílogo
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\13_arreglos_1d` — recorrido de arreglos
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\projects\src\print.s` — `print_i64` (entero → ASCII)
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\projects\src\input.s` — `parse_i64` (ASCII → entero)
