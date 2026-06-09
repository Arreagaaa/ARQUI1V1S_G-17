# Módulo 1 - Media Aritmética Ponderada

**Integrante 1 | `media.s` | Salida: `results/resultado_media.txt`**

Calcula la media ponderada de `TEMP` usando 30 lecturas reales de `lecturas.csv` y pesos `W_i = 1..30`.

## Fórmula

`MEDIA_PONDERADA = Σ(X_i * W_i) / ΣW_i`

## Salida esperada

```txt
MODULE=WEIGHTED_MEAN
TOTAL_VALUES=30
SUM_X=892
WEIGHT_SUM=465
WEIGHTED_MEAN=30
```

## Flujo

1. Abre `lecturas.csv`.
2. Lee la columna `TEMP`.
3. Calcula `SUM_X` y `WEIGHTED_MEAN`.
4. Escribe `results/resultado_media.txt`.

## Verificación

- `make modulo1`
- `make run1`
- `gdb-multiarch build/modulo_1_media`
