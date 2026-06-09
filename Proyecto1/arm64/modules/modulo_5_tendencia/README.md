# Módulo 5 - Tendencia Acumulada Avanzada

**Integrante 5 | `tendencia.s` | Salida: `results/resultado_tendencia.txt`**

Calcula incrementos, decrementos, rachas máximas, diferencia acumulada y tendencia final sobre 30 lecturas reales de `TEMP`.

## Regla

`DIF_i = X_i - X_(i-1)`

`ACCUM_DIFF = ΣDIF_i`

`ACCUM_DIFF > 0 => UP`

`ACCUM_DIFF < 0 => DOWN`

`ACCUM_DIFF = 0 => STABLE`

## Salida esperada

```txt
MODULE=ADVANCED_TREND
TOTAL_VALUES=30
INCREMENTS=18
DECREMENTS=10
MAX_UP_STREAK=12
MAX_DOWN_STREAK=6
ACCUM_DIFF=8
TREND=UP
```

## Estado actual

- El módulo es auto-contenido por ahora.
- `utils.s` sigue siendo la tarea grupal pendiente.
- Cuando `utils.s` esté listo, este README debe actualizarse con la versión compartida.

## Verificación

- `make modulo5`
- `make run5`
- `gdb-multiarch build/modulo_5_tendencia`
