# Módulo 4 - Predicción Lineal Simple

**Integrante 4 | `predicciones.s` | Salida: `results/resultado_prediccion.txt`**

Calcula tendencia lineal simple con 30 lecturas reales de `TEMP` usando punto fijo para conservar 2 decimales.

## Fórmulas

`DIFF = X_FINAL - X_INICIAL`

`AVG_CHANGE = DIFF / (N - 1)`

`NEXT_VALUE = X_FINAL + AVG_CHANGE`

## Salida esperada

```txt
MODULE=PREDICTION
TOTAL_VALUES=30
INITIAL_VALUE=22
FINAL_VALUE=30
TOTAL_DIFF=8
AVG_CHANGE=0.27
NEXT_VALUE=30.27
```

## Flujo

1. Lee `lecturas.csv`.
2. Toma el primer y último dato de `TEMP`.
3. Calcula diferencia, promedio y predicción.
4. Escribe `results/resultado_prediccion.txt`.

## Verificación

- `make modulo4`
- `make run4`
- `gdb-multiarch build/modulo_4_prediccion`
