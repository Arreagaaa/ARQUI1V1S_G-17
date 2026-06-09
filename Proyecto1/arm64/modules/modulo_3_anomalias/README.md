# Módulo 3 - Detección de Anomalías

**Integrante 3 | `anomalias.s` | Salida: `results/resultado_anomalias.txt`**

Detecta anomalías sobre 30 lecturas reales de `TEMP` con z-score entero.

## Regla

`Z = (X - MEAN) / STD_DEV`

`|Z| >= 2 => ANOMALIA`

## Salida esperada

```txt
MODULE=ANOMALY_DETECTION
TOTAL_VALUES=30
MEAN=29
STD_DEV=3
ANOMALIES=2
SYSTEM_RISK=MEDIUM
```

## Flujo

1. Abre `lecturas.csv`.
2. Lee la columna `TEMP`.
3. Calcula media, desviación y z-score.
4. Clasifica el riesgo y escribe `results/resultado_anomalias.txt`.

## Verificación

- `make modulo3`
- `make run3`
- `gdb-multiarch build/modulo_3_anomalias`
