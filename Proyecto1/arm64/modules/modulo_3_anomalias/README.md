# Módulo 3 — Detección Estadística de Anomalías

**Integrante 3** | Archivo: `modulo_3_anomalias.s` | Salida: `results/resultado_anomalias.txt`

---

## Fórmula Matemática

$$Z_i = \frac{X_i - \mu}{\sigma}$$

Anomalía $\iff |Z_i| \ge 2$

Es decir, **un valor es anómalo si se desvía al menos 2 desviaciones estándar de la media**.

### Clasificación de Riesgo

| Anomalías detectadas | SYSTEM_RISK |
|---|---|
| 0 | `NORMAL` |
| 1-3 | `MEDIUM` |
| 4 o más | `HIGH` |

---

## Entrada y Salida

* **Entrada:** Columna 1 del archivo `lecturas.csv` (TEMP).
* **Volumen:** 30 lecturas exactas.
* **Formato exacto de salida:**

```text
MODULE=ANOMALY_DETECTION
TOTAL_VALUES=30
MEAN=29
STD_DEV=3
ANOMALIES=4
SYSTEM_RISK=HIGH