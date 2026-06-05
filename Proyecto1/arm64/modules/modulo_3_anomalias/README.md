# Módulo 3 — Detección Estadística de Anomalías

**Integrante 3** | Archivo: `anomalias.s` | Salida: `../../results/resultado_anomalias.txt`

---

## Fórmula matemática

```
Z_i = (X_i - MEDIA) / DESV
anomalía ⟺ |Z_i| ≥ 2
```

Es decir, **un valor es anómalo si se desvía al menos 2 desviaciones estándar de la media**.

### Clasificación de riesgo

| Anomalías detectadas | SYSTEM_RISK |
|---|---|
| 0 | `NORMAL` |
| 1-3 | `MEDIUM` |
| 4 o más | `HIGH` |

---

## Columna del CSV que usa

- **Columna 1** del archivo `../../lecturas.csv` → `TEMP`
- 30 lecturas exactas

---

## Formato exacto de salida

```
MODULE=ANOMALY_DETECTION
TOTAL_VALUES=30
MEAN=29
STD_DEV=3
ANOMALIES=4
SYSTEM_RISK=HIGH
```

---

## Algoritmo esperado

```
1. Leer 30 valores de TEMP → values[30]
2. mean = Σ values / 30
3. diff_sq_sum = Σ (values[i] - mean)²
4. variance = diff_sq_sum / 30
5. std_dev = isqrt(variance)         // ver módulo 2
6. anomalies = 0
7. Para i = 0..29:
       diff = values[i] - mean
       if diff < 0: diff = -diff     // abs
       if diff >= 2 * std_dev:
           anomalies += 1
8. risk = NORMAL si anomalies==0, MEDIUM si 1..3, HIGH si >=4
9. Escribir 5 líneas en resultado_anomalias.txt
10. exit(0)
```

### Nota sobre división entera

`Z = (X - mean) / std_dev` implica una división con decimales. Para evitarla en ARM64 sin FPU, multiplicar el numerador por 100 (punto fijo) o comparar directamente:

```
|X - mean| ≥ 2 × std_dev     (no requiere división)
```

---

## Compilar y ejecutar

```bash
make utils
make modulo3
./build/modulo_3_anomalias
cat results/resultado_anomalias.txt
```

---

## Depurar con GDB

```bash
# Raspberry Pi
gdb ./build/modulo_3_anomalias
(gdb) set architecture aarch64
(gdb) break _start
(gdb) break count_anomalies
(gdb) run
(gdb) print $x0   # anomalies contadas
```

Con QEMU (PC):
```bash
make gdb3          # terminal 1 (servidor)
gdb-multiarch build/modulo_3_anomalias  # terminal 2
(gdb) set architecture aarch64
(gdb) target remote :1234
(gdb) break count_anomalies
(gdb) continue
```

### Breakpoints sugeridos

| Punto | Por qué |
|---|---|
| `compute_mean` | Verificar media |
| `compute_std_dev` | Verificar desv. estándar |
| `count_anomalies` | Inspeccionar contador antes/después |
| `classify` | Ver el branching NORMAL/MEDIUM/HIGH |

---

## Evidencia para la defensa

- Sesión GDB con el contador `anomalies` en distintos puntos
- `cat results/resultado_anomalias.txt` con el resultado
- Explicación de por qué |Z|≥2 (regla del 95% en distribución normal)

---

## Referencias

- Módulo 2 (`varianza.s`) — reutilizar `isqrt` o replicar la lógica
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\06_loops_while_for` — loops con contador
- `D:\Projects\USAC\ARQUI1_1S2026\02_ARM64\lessons\11_abi_y_multiarchivo` — convención de registros
