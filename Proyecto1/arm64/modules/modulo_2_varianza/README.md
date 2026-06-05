# Módulo 2 — Varianza y Desviación Estándar

**Integrante 2** | Archivo: `varianza.s` | Salida: `../../results/resultado_varianza.txt`

---

## Fórmulas matemáticas

```
MEDIA = ΣX / N
VAR   = Σ(X_i - MEDIA)² / N
DESV  = √(VAR)              (raíz cuadrada entera)
```

---

## Columna del CSV que usa

- **Columna 1** del archivo `../../lecturas.csv` → `TEMP`
- 30 lecturas exactas (líneas 2-31)

---

## Formato exacto de salida

```
MODULE=VARIANCE
TOTAL_VALUES=30
MEAN=31
VARIANCE=18
STD_DEV=4
```

> ⚠️ Respetar mayúsculas, el orden de líneas y la ausencia de espacios alrededor del `=`.

---

## Algoritmo esperado

```
1. Leer 30 valores de TEMP → values[30]
2. sum = Σ values[i]
3. mean = sum / 30                        // división entera
4. acc = 0
5. Para i = 0..29:
       diff = values[i] - mean
       acc += diff * diff
6. variance = acc / 30
7. std_dev = isqrt(variance)              // ver subrutina abajo
8. Escribir 4 líneas en resultado_varianza.txt
9. exit(0)
```

### Subrutina `isqrt(x)` sugerida (babilónica)

```
guess = x
while guess*guess > x:
    guess = (guess + x/guess) / 2
return guess
```

Limitación: división entera. Si `x` no es cuadrado perfecto, `isqrt` devuelve el piso. El enunciado da `VARIANCE=18 / STD_DEV=4` (porque 4²=16 ≤ 18 < 25=5²).

---

## Compilar y ejecutar

```bash
# Desde arm64/
make utils
make modulo2
./build/modulo_2_varianza
cat results/resultado_varianza.txt
```

---

## Depurar con GDB

```bash
# En Raspberry Pi
gdb ./build/modulo_2_varianza
(gdb) set architecture aarch64
(gdb) break _start
(gdb) break isqrt
(gdb) run
(gdb) info registers
(gdb) print $x0        # x pasado a isqrt
(gdb) continue
```

Con QEMU:
```bash
make gdb2            # terminal 1
gdb-multiarch build/modulo_2_varianza    # terminal 2
(gdb) set architecture aarch64
(gdb) target remote :1234
(gdb) break isqrt
(gdb) continue
```

### Breakpoints sugeridos

| Punto | Por qué |
|---|---|
| `_start` | Inicio del módulo |
| `compute_mean` | Validar cálculo de media |
| `compute_variance` | Verificar suma de cuadrados |
| `isqrt` | Inspeccionar input/output de raíz cuadrada |

---

## Evidencia para la defensa

- Sesión GDB con `info registers` antes y después de `isqrt`
- `cat results/resultado_varianza.txt` con el resultado
- Explicación oral del algoritmo babilónico iterativo

---

## Referencias

- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\13_arreglos_1d` — recorrido de arreglos
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\15_matrices_operaciones` — operaciones con arreglos
