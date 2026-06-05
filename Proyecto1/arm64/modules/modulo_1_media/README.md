# Módulo 1 — Media Aritmética Ponderada

**Integrante 1** | Archivo: `media.s` | Salida: `../../results/resultado_media.txt`
**Estado**: ✅ Implementado y listo para probar en Ubuntu

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

## Salida esperada (con `lecturas.csv` actual)

El módulo escribe en `../../results/resultado_media.txt`:

```
MODULE=WEIGHTED_MEAN
TOTAL_VALUES=30
SUM_X=892
WEIGHT_SUM=465
WEIGHTED_MEAN=30
```

**Cálculo verificado a mano**:
- `SUM_X` = 265 + 311 + 316 = **892** (Σ de los 30 valores TEMP)
- `Σ(X_i * W_i)` = 1540 + 4772 + 8050 = **14362**
- `WEIGHTED_MEAN` = 14362 / 465 = **30** (división entera)

> ⚠️ **El enunciado es estricto**: cualquier desviación del formato (espacios, mayúsculas, orden de líneas) puede invalidar la rúbrica. Usar exactamente `MODULE=`, `TOTAL_VALUES=`, `SUM_X=`, `WEIGHT_SUM=`, `WEIGHTED_MEAN=`.

Si `lecturas.csv` cambia, recalcular con este comando Python:
```python
import csv
xs = []
with open('../../lecturas.csv') as f:
    r = csv.reader(f)
    next(r)  # saltar header
    for row in r:
        if row and row[0] != '$':
            xs.append(int(row[1]))
print('SUM_X =', sum(xs))
print('WEIGHTED_MEAN =', sum(x*(i+1) for i,x in enumerate(xs)) // 465)
```

---

## Algoritmo implementado en `media.s`

```
1. Abrir ../lecturas.csv                   (syscall openat)
2. Para i = 0..29:
       read(1 línea)                       (syscall read)
       parse_csv_column(col=1) → X_i      (subrutina propia)
       values_buf[i] = X_i                 (almacenar en buffer 30×8B)
3. close(lecturas.csv)                     (syscall close)
4. sum_x = sum_values(values_buf)          (subrutina propia)
5. mean  = weighted_mean(values_buf)       (SUBRUTINA PROPIA — req. enunciado)
6. Construir 5 líneas ASCIIZ en out_buf    (copy_str + int_to_ascii)
7. Abrir results/resultado_media.txt       (syscall openat, O_WRONLY|O_CREAT|O_TRUNC, 0644)
8. write(out_buf) + close                  (syscalls write, close)
9. exit(0)                                 (syscall exit)
```

### Sugerencia de registros (lo que usa `media.s`)

| Registro | Uso |
|---|---|
| `x0`-`x2` | argumentos syscall / retorno subrutina |
| `x8` | número de syscall |
| `x9` | puntero base del arreglo (en `_start` también cursor de output) |
| `x10` | índice del loop / offset |
| `x19` | **callee-saved**: fd actual (entrada o salida) |
| `x20` | **callee-saved**: contador de líneas / longitud output |
| `x21` | **callee-saved**: `sum_x` |
| `x22` | **callee-saved**: `weighted_mean` |
| `x29`/`x30` | frame pointer / link register (prólogo/epílogo) |

### Subrutinas propias definidas en `media.s` (100% auto-contenido)

> ✅ `media.s` **no usa `.extern`** — no depende de `utils.s` stub. Cuando el grupo implemente `utils.s`, las funciones de I/O se podrán consolidar sin romper `media.s`.

| Subrutina | Propósito | Convocante |
|---|---|---|
| `parse_csv_column(buf, col) → int` | Extrae el valor entero de la columna N de una línea CSV | lectura |
| `sum_values(buf) → int` | Suma los 30 enteros i64 del arreglo | cálculo |
| **`weighted_mean(buf) → int`** | **Media ponderada entera** (requisito enunciado §9.3 #10) | cálculo |
| `int_to_ascii(val, dst) → ptr` | Convierte entero ≥ 0 a ASCII decimal (con caso especial 0) | output |
| `copy_str(src, dst) → ptr` | Copia string ASCIIZ y avanza el puntero destino | output |

`int_to_ascii` y `copy_str` son auxiliares para construir el archivo de salida; no son parte del cálculo matemático.

---

## Quickstart Ubuntu (1 minuto)

```bash
# 1) Instalar toolchain (una sola vez)
sudo apt update
sudo apt install -y binutils-aarch64-linux-gnu qemu-user

# 2) Compilar y ejecutar (CWD debe ser arm64/)
cd Proyecto1/arm64
make run1

# 3) Verificar salida
cat results/resultado_media.txt
# Debe imprimir las 5 líneas con SUM_X=892 y WEIGHTED_MEAN=30
```

> **CWD importante**: `media.s` usa paths relativos `lecturas.csv` y `results/resultado_media.txt`. Siempre ejecutar desde `Proyecto1/arm64/` (es lo que hace `make run1` internamente).

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
