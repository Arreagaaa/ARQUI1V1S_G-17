# Módulo 2 - Varianza y Desviación Estándar

**Integrante 2 | `varianza.s` | Salida: `results/resultado_varianza.txt`**

Calcula media, varianza y desviación estándar sobre 30 lecturas reales de `TEMP` desde `lecturas.csv`.

## Fórmulas

`MEAN = ΣX / N`

`VARIANCE = Σ(X - MEAN)^2 / N`

`STD_DEV = sqrt(VARIANCE)`

## Salida esperada

```txt
MODULE=VARIANCE
TOTAL_VALUES=30
MEAN=29
VARIANCE=10
STD_DEV=3
```

## Flujo

1. Lee `lecturas.csv`.
2. Carga 30 valores de `TEMP`.
3. Calcula media, varianza y `isqrt`.
4. Escribe `results/resultado_varianza.txt`.

## Verificación

- `make modulo2`
- `make run2`
- `gdb-multiarch build/modulo_2_varianza`
