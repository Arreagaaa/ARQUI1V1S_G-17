# Módulo 5 — Tendencia Acumulada Avanzada

**Integrante 5** | Archivo: `tendencia.s` | Salida: `../../results/resultado_tendencia.txt`

---

## Fórmulas matemáticas

```
DIF_i          = X_i - X_(i-1)         para i = 1..29
INCREMENTS     = #{i : DIF_i > 0}
DECREMENTS     = #{i : DIF_i < 0}
MAX_UP_STREAK  = máx longitud de una racha de DIF_i > 0 consecutivos
MAX_DOWN_STREAK= máx longitud de una racha de DIF_i < 0 consecutivos
DIF_ACUM       = Σ DIF_i
TREND          = UP    si DIF_ACUM > 0
                 DOWN  si DIF_ACUM < 0
                 STABLE si DIF_ACUM == 0
```

---

## Columna del CSV que usa

- **Columna 1** del archivo `../../lecturas.csv` → `TEMP`

---

## Formato exacto de salida

```
MODULE=ADVANCED_TREND
TOTAL_VALUES=30
INCREMENTS=18
DECREMENTS=10
MAX_UP_STREAK=5
MAX_DOWN_STREAK=3
ACCUM_DIFF=7
TREND=UP
```

---

## Algoritmo esperado

```
1. Leer 30 valores de TEMP → values[30]
2. inc = 0, dec = 0
3. curr_up = 0, curr_down = 0
4. max_up = 0, max_down = 0
5. acc = 0
6. Para i = 1..29:
       diff = values[i] - values[i-1]
       acc += diff
       if diff > 0:
           inc++
           curr_up++
           curr_down = 0
           if curr_up > max_up: max_up = curr_up
       elif diff < 0:
           dec++
           curr_down++
           curr_up = 0
           if curr_down > max_down: max_down = curr_down
       else:
           curr_up = 0
           curr_down = 0
7. trend = (acc > 0) ? UP : (acc < 0) ? DOWN : STABLE
8. Imprimir 7 líneas en resultado_tendencia.txt
9. exit(0)
```

### Sugerencia de registros

| Registro | Uso |
|---|---|
| `x9` | puntero a `values` |
| `x10` | índice del loop (i) |
| `x11` | `diff` actual |
| `x12` | `acc` (DIF_ACUM) |
| `x13` | `inc` |
| `x14` | `dec` |
| `x15` | `curr_up` |
| `x16` | `curr_down` |
| `x17` | `max_up` |
| `x18` | `max_down` |

---

## Compilar y ejecutar

```bash
make utils
make modulo5
./build/modulo_5_tendencia
cat results/resultado_tendencia.txt
```

---

## Depurar con GDB

```bash
gdb ./build/modulo_5_tendencia
(gdb) set architecture aarch64
(gdb) break _start
(gdb) break compute_tendency
(gdb) run
(gdb) info registers
(gdb) print/x $x12    # acc
(gdb) print/x $x13    # inc
(gdb) print/x $x14    # dec
```

Con QEMU:
```bash
make gdb5
# terminal 2
gdb-multiarch build/modulo_5_tendencia
(gdb) set architecture aarch64
(gdb) target remote :1234
(gdb) break _start
(gdb) continue
```

### Breakpoints sugeridos

| Punto | Por qué |
|---|---|
| `_start` | Inicio |
| Dentro del loop, i=1 | Validar `diff` para 1ra transición |
| Después del loop | Validar contadores y `acc` |
| Selección de `TREND` | Verificar branching |

---

## Evidencia para la defensa

- Sesión GDB con `info registers` mostrando `inc`, `dec`, `acc`, `max_up`, `max_down`
- `cat results/resultado_tendencia.txt`
- Explicación oral de la lógica de rachas con un diagrama de ejemplo

---

## Referencias

- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\06_loops_while_for` — loops con branch
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\10_stack_y_funciones` — preservación de registros
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\11_abi_y_multiarchivo` — subrutinas con ABI
