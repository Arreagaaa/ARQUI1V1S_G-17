# Módulo 4 — Predicción Lineal Simple

**Integrante 4** | Archivo: `prediccion.s` | Salida: `../../results/resultado_prediccion.txt`

---

## Fórmulas matemáticas

```
DIF              = X_FINAL - X_INICIAL
PROMEDIO_CAMBIO  = DIF / (N - 1)
PREDICCION       = X_FINAL + PROMEDIO_CAMBIO
```

Donde:
- `X_INICIAL` = `values[0]` (primera lectura)
- `X_FINAL` = `values[29]` (última lectura)
- `N = 30`

---

## Columna del CSV que usa

- **Columna 1** del archivo `../../lecturas.csv` → `TEMP`

---

## Formato exacto de salida

```
MODULE=PREDICTION
INITIAL_VALUE=28
FINAL_VALUE=34
TOTAL_DIFF=6
AVG_CHANGE=0.20
NEXT_VALUE=34.20
```

> ⚠️ `AVG_CHANGE` y `NEXT_VALUE` tienen **2 decimales** (formato "%.2f").

---

## Algoritmo esperado

```
1. Leer 30 valores de TEMP → values[30]
2. initial = values[0]
3. final = values[29]
4. diff = final - initial
5. avg_change = diff / 29
6. next_value = final + avg_change
7. Imprimir:
       INITIAL_VALUE=<initial>           (entero)
       FINAL_VALUE=<final>               (entero)
       TOTAL_DIFF=<diff>                 (entero)
       AVG_CHANGE=<avg_change>           (2 decimales)
       NEXT_VALUE=<next_value>           (2 decimales)
8. exit(0)
```

### Punto fijo para decimales

ARM64 sin FPU (configuración por defecto): convertir todo a punto fijo ×100.

```
avg_change_fp = (diff * 100) / 29          // ej. 6 * 100 / 29 = 20 (representa 0.20)
next_value_fp = (final * 100) + avg_change_fp
// Imprimir next_value_fp como "entero.decimal":
//   parte_entera = next_value_fp / 100
//   parte_decimal = next_value_fp % 100
```

Helper de formato:
```python
# Plantilla Python (referencia)
def fmt(fp):  # fp = entero con 2 decimales
    return f"{fp // 100}.{fp % 100:02d}"
```

---

## Compilar y ejecutar

```bash
make utils
make modulo4
./build/modulo_4_prediccion
cat results/resultado_prediccion.txt
```

---

## Depurar con GDB

```bash
gdb ./build/modulo_4_prediccion
(gdb) set architecture aarch64
(gdb) break _start
(gdb) run
(gdb) print $x0    # initial
(gdb) print $x1    # final
(gdb) print $x2    # diff
(gdb) step
```

Con QEMU:
```bash
make gdb4
# terminal 2
gdb-multiarch build/modulo_4_prediccion
(gdb) set architecture aarch64
(gdb) target remote :1234
(gdb) break _start
(gdb) continue
```

### Breakpoints sugeridos

| Punto | Por qué |
|---|---|
| `_start` | Inicio |
| Después de leer `values[0]` | Validar `INITIAL_VALUE` |
| Después de leer `values[29]` | Validar `FINAL_VALUE` |
| Subrutina de formato | Verificar `0.20` y `34.20` |

---

## Evidencia para la defensa

- Sesión GDB con los 4 valores clave (`initial`, `final`, `diff`, `next_value`)
- `cat results/resultado_prediccion.txt` con el resultado
- Explicación del truco de punto fijo ×100

---

## Referencias

- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\07_alu_matematica_basica` — mul, div
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\projects\src\print.s` — `print_i64` para enteros
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\12_tipos_y_extension_signo_cero` — `sxtw` para signo
