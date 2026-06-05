// =============================================================================
// media.s — Módulo 1: Media aritmética ponderada
// Integrante 1
//
// Lee la columna TEMP del archivo ../lecturas.csv (30 datos reales),
// calcula la media ponderada con pesos W_i = i (W_1=1, W_2=2, ..., W_30=30)
// y escribe el resultado en ../results/resultado_media.txt.
//
// Fórmula (enunciado ACYE1 §10.1):
//   MEDIA_PONDERADA = Σ(X_i * W_i) / ΣW_i
//   con W_i = i  (i = 1..30)
//
// Formato exacto de salida (enunciado §10.1):
//   MODULE=WEIGHTED_MEAN
//   TOTAL_VALUES=30
//   SUM_X=920
//   WEIGHT_SUM=465
//   WEIGHTED_MEAN=31
//
// Requisitos (enunciado §9.3):
//   1. Ensamblador ARM64/AArch64
//   2. Compilable con `as` / `ld` (vía Makefile en directorio padre)
//   3. Lee datos desde ../lecturas.csv (vía utils_open_csv / utils_read_int_column)
//   4. Procesa exactamente 30 datos
//   5. Salida en ../results/resultado_media.txt
//   6. Implementa conversión ASCII ↔ entero (provista por utils.s)
//   7. Al menos una subrutina propia (la que calcula la media ponderada)
//   8. Defendible individualmente
//
// TODO: Integrante 1
//   - Leer la columna TEMP (índice 1) con utils_read_int_column
//   - Recorrer las 30 lecturas acumulando ΣX y ΣX*W (W_i = i)
//   - Calcular WEIGHT_SUM = 30*31/2 = 465 (constante)
//   - Dividir SUM_X_WEIGHTED por WEIGHT_SUM (división entera)
//   - Formatear las 4 líneas del resultado
//   - Escribir con utils_write_result
// =============================================================================

.section .data
msg_module:        .ascii "MODULE=WEIGHTED_MEAN\n"
msg_module_len = . - msg_module
msg_total:         .ascii "TOTAL_VALUES=30\n"
msg_total_len = . - msg_total
msg_sumx:          .ascii "SUM_X="
msg_sumx_len = . - msg_sumx
msg_weightsum:     .ascii "WEIGHT_SUM=465\n"
msg_weightsum_len = . - msg_weightsum
msg_mean:          .ascii "WEIGHTED_MEAN="
msg_mean_len = . - msg_mean
msg_nl:            .ascii "\n"
msg_nl_len = . - msg_nl

.equ N_VALUES,    30
.equ WEIGHT_SUM,  465          // Σ(i) para i=1..30 = 30*31/2

.section .bss
.lcomm values,     8 * N_VALUES     // buffer para los 30 enteros de la columna
.lcomm result_buf, 256              // buffer de salida (líneas concatenadas)

.section .text
.global _start

_start:
    // TODO: implementar la lógica del módulo
    // 1. utils_open_csv("../lecturas.csv") → fd
    // 2. utils_read_int_column(1, values) → 30 enteros en values
    // 3. Recorrer values calculando:
    //      sum_x            = Σ values[i]
    //      sum_x_weighted   = Σ (values[i] * (i+1))   // pesos 1..30
    // 4. mean = sum_x_weighted / WEIGHT_SUM
    // 5. Construir result_buf con las 4 líneas del formato
    // 6. utils_write_result(result_buf, len) → ../results/resultado_media.txt
    // 7. utils_exit(0)

    mov x0, #0
    bl utils_exit

// -----------------------------------------------------------------------------
// Subrutina propia: weighted_mean
//   Entradas:
//     x0 = puntero al arreglo de N_VALUES enteros (8 bytes cada uno)
//   Salida:
//     x0 = media ponderada (entera)
//   Registros preservados: x19-x28 según ABI AArch64
// -----------------------------------------------------------------------------
weighted_mean:
    // TODO: implementar
    //   acc = 0
    //   for i in 0..N_VALUES-1:
    //       weight = i + 1
    //       acc += values[i] * weight
    //   return acc / WEIGHT_SUM
    ret
