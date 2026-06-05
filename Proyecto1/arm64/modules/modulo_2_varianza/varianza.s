// =============================================================================
// varianza.s — Módulo 2: Varianza y desviación estándar
// Integrante 2
//
// Lee la columna TEMP del archivo ../lecturas.csv (30 datos reales),
// calcula la varianza y la desviación estándar, y escribe el resultado
// en ../results/resultado_varianza.txt.
//
// Fórmulas (enunciado ACYE1 §10.2):
//   MEDIA   = ΣX / N
//   VAR     = Σ(X_i - MEDIA)² / N
//   DESV    = sqrt(VAR)
//
// Formato exacto de salida (enunciado §10.2):
//   MODULE=VARIANCE
//   TOTAL_VALUES=30
//   MEAN=31
//   VARIANCE=18
//   STD_DEV=4
//
// TODO: Integrante 2
//   - Reutilizar utils_read_int_column para obtener values[30]
//   - Calcular la media primero
//   - Calcular la suma de cuadrados de las desviaciones
//   - Dividir entre N para varianza
//   - Calcular sqrt entero de VAR (algoritmo babilónico iterativo
//     o método de búsqueda binaria)
// =============================================================================

.section .data
msg_module:       .ascii "MODULE=VARIANCE\n"
msg_module_len = . - msg_module
msg_total:        .ascii "TOTAL_VALUES=30\n"
msg_total_len = . - msg_total
msg_mean:         .ascii "MEAN="
msg_mean_len = . - msg_mean
msg_variance:     .ascii "VARIANCE="
msg_variance_len = . - msg_variance
msg_stddev:       .ascii "STD_DEV="
msg_stddev_len = . - msg_stddev
msg_nl:           .ascii "\n"
msg_nl_len = . - msg_nl

.equ N_VALUES, 30

.section .bss
.lcomm values,     8 * N_VALUES
.lcomm result_buf, 256

.section .text
.global _start

_start:
    // TODO:
    //   1. utils_open_csv + utils_read_int_column(1, values)
    //   2. mean = compute_mean(values)
    //   3. variance = compute_variance(values, mean)
    //   4. std_dev = isqrt(variance)
    //   5. utils_write_result(result_buf, len)
    //   6. utils_exit(0)

    mov x0, #0
    bl utils_exit

// -----------------------------------------------------------------------------
// Subrutinas propias:
//   compute_mean(values) → media entera
//   compute_variance(values, mean) → varianza entera
//   isqrt(x) → raíz cuadrada entera (entero positivo)
// -----------------------------------------------------------------------------
compute_mean:
    // TODO
    ret

compute_variance:
    // TODO
    ret

isqrt:
    // TODO: Newton-Raphson o búsqueda binaria
    //   guess = x / 2
    //   while guess^2 > x: guess = (guess + x/guess) / 2
    ret
