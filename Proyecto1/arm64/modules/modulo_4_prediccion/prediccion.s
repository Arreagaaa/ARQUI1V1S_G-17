// =============================================================================
// prediccion.s — Módulo 4: Predicción lineal simple
// Integrante 4
//
// Lee la columna TEMP del archivo ../lecturas.csv (30 datos reales),
// realiza una regresión lineal simple (1 variable) y predice el valor
// siguiente a la última lectura.
//
// Fórmulas (enunciado ACYE1 §10.4):
//   DIF            = XFINAL - XINICIAL
//   PROMEDIO_CAMBIO = DIF / (N - 1)
//   PREDICCION     = XFINAL + PROMEDIO_CAMBIO
//
// Formato exacto de salida:
//   MODULE=PREDICTION
//   INITIAL_VALUE=28
//   FINAL_VALUE=34
//   TOTAL_DIFF=6
//   AVG_CHANGE=0.20
//   NEXT_VALUE=34.20
//
// TODO: Integrante 4
//   - Leer 30 valores
//   - initial = values[0]
//   - final = values[29]
//   - diff = final - initial
//   - avg_change = diff / 29  (división con decimales: usar punto fijo *100)
//   - next_value = final + avg_change (en punto fijo)
//   - Imprimir AVG_CHANGE y NEXT_VALUE con 2 decimales
// =============================================================================

.section .data
msg_module:        .ascii "MODULE=PREDICTION\n"
msg_module_len = . - msg_module
msg_initial:       .ascii "INITIAL_VALUE="
msg_initial_len = . - msg_initial
msg_final:         .ascii "FINAL_VALUE="
msg_final_len = . - msg_final
msg_diff:          .ascii "TOTAL_DIFF="
msg_diff_len = . - msg_diff
msg_avg:           .ascii "AVG_CHANGE="
msg_avg_len = . - msg_avg
msg_next:          .ascii "NEXT_VALUE="
msg_next_len = . - msg_next
msg_nl:            .ascii "\n"
msg_nl_len = . - msg_nl

.equ N_VALUES, 30
.equ N_MINUS_1, 29
.equ FIXED_POINT_SCALE, 100    // 2 decimales (0.20 → 20, 34.20 → 3420)

.section .bss
.lcomm values,     8 * N_VALUES
.lcomm result_buf, 256

.section .text
.global _start

_start:
    // TODO:
    //   1. utils_open_csv + utils_read_int_column(1, values)
    //   2. initial = values[0]
    //   3. final = values[29]
    //   4. diff = final - initial
    //   5. avg_change_fp = (diff * 100) / 29    // punto fijo
    //   6. next_value_fp = (final * 100) + avg_change_fp
    //   7. utils_write_result con avg_change y next_value en formato
    //      "0.20" y "34.20" (2 decimales)
    //   8. utils_exit(0)

    mov x0, #0
    bl utils_exit

// Subrutinas propias:
format_fixed_point: ret   // convierte entero con escala (ej. 3420 → "34.20")
