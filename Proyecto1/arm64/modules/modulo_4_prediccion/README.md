# Módulo 4 — Predicción Lineal Simple

**Integrante 4** | Archivo: `predicciones.s` | Salida: `../../results/resultado_prediccion.txt`

**Estado:** ✅ Implementado y verificado en QEMU ARM64

---

## Objetivo

Realizar una predicción lineal simple utilizando las 30 lecturas de temperatura almacenadas en `lecturas.csv`.

El algoritmo toma la primera y la última lectura, calcula el cambio promedio entre ellas y estima el siguiente valor esperado.

---

## Fórmulas matemáticas

```text
TOTAL_DIFF = FINAL_VALUE - INITIAL_VALUE

AVG_CHANGE = TOTAL_DIFF / (TOTAL_VALUES - 1)

NEXT_VALUE = FINAL_VALUE + AVG_CHANGE
```

Donde:

* `INITIAL_VALUE` = primera lectura de temperatura
* `FINAL_VALUE` = última lectura de temperatura
* `TOTAL_VALUES` = 30

---

## Columna utilizada

Se utiliza la columna:

```text
TEMP
```

ubicada en la columna 1 del archivo:

```text
../../lecturas.csv
```

---

## Algoritmo implementado

```text
1. Abrir lecturas.csv
2. Leer las 30 temperaturas
3. Guardar la primera lectura
4. Guardar la última lectura
5. Calcular:

      TOTAL_DIFF = FINAL - INITIAL

6. Calcular:

      AVG_CHANGE = TOTAL_DIFF / 29

7. Calcular:

      NEXT_VALUE = FINAL + AVG_CHANGE

8. Generar resultado_prediccion.txt

9. Finalizar ejecución
```

---

## Punto fijo (2 decimales)

Para evitar el uso de punto flotante en ARM64, los cálculos se realizan utilizando punto fijo ×100.

```text
avg_change_fp = (TOTAL_DIFF * 100) / 29

next_value_fp = (FINAL_VALUE * 100) + avg_change_fp
```

Impresión:

```text
parte_entera  = valor_fp / 100
parte_decimal = valor_fp % 100
```

Ejemplo:

```text
3027  →  30.27
```

---

## Salida esperada con lecturas.csv actual

```text
MODULE=PREDICTION
TOTAL_VALUES=30
INITIAL_VALUE=22
FINAL_VALUE=30
TOTAL_DIFF=8
AVG_CHANGE=0.27
NEXT_VALUE=30.27
```

---

## Formato exacto de salida

```text
MODULE=PREDICTION
TOTAL_VALUES=<cantidad>
INITIAL_VALUE=<valor>
FINAL_VALUE=<valor>
TOTAL_DIFF=<valor>
AVG_CHANGE=<valor_con_2_decimales>
NEXT_VALUE=<valor_con_2_decimales>
```

Observaciones:

* `INITIAL_VALUE` es entero.
* `FINAL_VALUE` es entero.
* `TOTAL_DIFF` es entero.
* `AVG_CHANGE` se imprime con 2 decimales.
* `NEXT_VALUE` se imprime con 2 decimales.

---

## Compilación

Desde `Proyecto1/arm64`:

```bash
make modulo4
```

Genera:

```text
build/modulo_4_prediccion
```

---

## Ejecución en Raspberry Pi

```bash
./build/modulo_4_prediccion
```

Verificar:

```bash
cat results/resultado_prediccion.txt
```

---

## Ejecución con QEMU

```bash
make modulo4
qemu-aarch64 build/modulo_4_prediccion
cat results/resultado_prediccion.txt
```

Salida verificada:

```text
MODULE=PREDICTION
TOTAL_VALUES=30
INITIAL_VALUE=22
FINAL_VALUE=30
TOTAL_DIFF=8
AVG_CHANGE=0.27
NEXT_VALUE=30.27
```

---

## Depuración con GDB

Servidor:

```bash
qemu-aarch64 -g 1234 build/modulo_4_prediccion
```

Cliente:

```bash
gdb-multiarch build/modulo_4_prediccion

(gdb) set architecture aarch64
(gdb) target remote :1234
(gdb) break _start
(gdb) continue
```

---

## Breakpoints recomendados

| Punto                              | Verificación         |
| ---------------------------------- | -------------------- |
| `_start`                           | Inicio del programa  |
| Después de leer la primera lectura | INITIAL_VALUE        |
| Después de leer la última lectura  | FINAL_VALUE          |
| Antes de escribir el archivo       | Valores calculados   |
| Rutina de impresión decimal        | Formato 0.27 y 30.27 |

---

## Evidencia para la defensa

1. Compilación exitosa del módulo.
2. Ejecución en Raspberry Pi o QEMU.
3. Archivo `resultado_prediccion.txt` generado correctamente.
4. Explicación del uso de punto fijo ×100.
5. Explicación de las fórmulas:

```text
TOTAL_DIFF = FINAL_VALUE - INITIAL_VALUE

AVG_CHANGE = TOTAL_DIFF / 29

NEXT_VALUE = FINAL_VALUE + AVG_CHANGE
```

---

## Referencias

* ARM64 AArch64 Assembly
* Syscalls Linux ARM64
* Material del curso ACYE1
* Lecciones de aritmética entera y división en ARM64
