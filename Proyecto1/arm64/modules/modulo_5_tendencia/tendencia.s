// =============================================================================
// tendencia.s — Módulo 5: Tendencia acumulada avanzada
// Integrante 5 — Grupo 17 — ACYE1 Invernadero Inteligente IoT
// =============================================================================
// Lee la columna TEMP del archivo lecturas.csv (30 datos reales),
// calcula métricas de tendencia acumulada (incrementos, decrementos,
// rachas, diferencia acumulada y dirección de tendencia) y escribe
// el resultado en results/resultado_tendencia.txt.
// =============================================================================

// -----------------------------------------------------------------------------
// Símbolos externos de utils.s
// -----------------------------------------------------------------------------
.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit
.extern utils_read_column_config

// -----------------------------------------------------------------------------
// Constantes del módulo
// -----------------------------------------------------------------------------
.equ N_VALUES,        30
.equ TARGET_COL,      1

// =============================================================================
// Sección .rodata — strings de solo lectura
// =============================================================================
.section .rodata
.align 3

out_path:      .asciz "results/resultado_tendencia.txt"

lbl_module:    .asciz "MODULE=ADVANCED_TREND\n"
lbl_total:     .asciz "TOTAL_VALUES=30\n"
lbl_incr:      .asciz "INCREMENTS="
lbl_decr:      .asciz "DECREMENTS="
lbl_maxup:     .asciz "MAX_UP_STREAK="
lbl_maxdn:     .asciz "MAX_DOWN_STREAK="
lbl_accum:     .asciz "ACCUM_DIFF="
lbl_trend:     .asciz "TREND="
str_up:        .asciz "UP"
str_down:      .asciz "DOWN"
str_stable:    .asciz "STABLE"
nl:            .asciz "\n"
minus_sign:    .asciz "-"

// =============================================================================
// Sección .bss — buffers en memoria no inicializada
// =============================================================================
.section .bss
.align 3

values_buf:    .skip 8 * N_VALUES
out_buf:       .skip 512

// =============================================================================
// Sección .text — código ejecutable
// =============================================================================
.section .text
.global _start

_start:
    // ---- 1) Abrir lecturas.csv ----
    bl   utils_open_csv
    mov  x19, x0

    // ---- 2) Leer columna configurada (default: 1 = TEMP) ----
    mov  x0, #5
    bl   utils_read_column_config
    mov  x1, x0
    mov  x0, x19
    adr  x2, values_buf
    bl   utils_read_int_column
    cmp  x0, #N_VALUES
    b.ne error_exit

    // ---- 3) Cerrar archivo de entrada ----
    mov  x0, x19
    bl   utils_close_csv

    // ---- 4) Calcular tendencia ----
    adr  x0, values_buf
    bl   compute_tendency
    // x20 = INCREMENTS
    // x21 = DECREMENTS
    // x22 = MAX_UP_STREAK
    // x23 = MAX_DOWN_STREAK
    // x24 = ACCUM_DIFF (con signo)

    // ---- 5) Construir archivo de salida en out_buf ----
    adr  x9, out_buf

    // L1: "MODULE=ADVANCED_TREND\n"
    adr  x0, lbl_module
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // L2: "TOTAL_VALUES=30\n"
    adr  x0, lbl_total
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // L3: "INCREMENTS=<valor>\n"
    adr  x0, lbl_incr
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x20
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // L4: "DECREMENTS=<valor>\n"
    adr  x0, lbl_decr
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x21
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // L5: "MAX_UP_STREAK=<valor>\n"
    adr  x0, lbl_maxup
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x22
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // L6: "MAX_DOWN_STREAK=<valor>\n"
    adr  x0, lbl_maxdn
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x23
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // L7: "ACCUM_DIFF=<valor>\n"
    adr  x0, lbl_accum
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    cmp  x24, #0
    b.ge accum_positive
    adr  x0, minus_sign
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    neg  x0, x24
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    b    accum_newline
accum_positive:
    mov  x0, x24
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
accum_newline:
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // L8: "TREND=<UP|DOWN|STABLE>\n"
    adr  x0, lbl_trend
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    cmp  x24, #0
    b.gt trend_up
    b.lt trend_down
    adr  x0, str_stable
    b    trend_write
trend_up:
    adr  x0, str_up
    b    trend_write
trend_down:
    adr  x0, str_down
trend_write:
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // ---- 6) Escribir archivo de resultados ----
    adr  x10, out_buf
    sub  x2, x9, x10
    adr  x0, out_path
    adr  x1, out_buf
    bl   utils_write_result

    // ---- 7) Salir con éxito ----
    mov  x0, #0
    bl   utils_exit

error_exit:
    mov  x0, #1
    bl   utils_exit

// =============================================================================
// compute_tendency — SUBRUTINA PROPIA OBLIGATORIA (Módulo 5)
// =============================================================================
compute_tendency:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp

    mov  x20, #0
    mov  x21, #0
    mov  x22, #0
    mov  x23, #0
    mov  x24, #0

    mov  x9, x0
    mov  x10, #1
    mov  x14, #0
    mov  x15, #0

    ldr  x11, [x9]

ct_loop:
    cmp  x10, #N_VALUES
    b.ge ct_done

    lsl  x16, x10, #3
    ldr  x12, [x9, x16]

    sub  x13, x12, x11

    add  x24, x24, x13

    cmp  x13, #0
    b.gt ct_positive
    b.lt ct_negative
    mov  x14, #0
    mov  x15, #0
    b    ct_next

ct_positive:
    add  x20, x20, #1
    add  x14, x14, #1
    mov  x15, #0
    cmp  x14, x22
    b.le ct_next
    mov  x22, x14
    b    ct_next

ct_negative:
    add  x21, x21, #1
    add  x15, x15, #1
    mov  x14, #0
    cmp  x15, x23
    b.le ct_next
    mov  x23, x15
    b    ct_next

ct_next:
    mov  x11, x12
    add  x10, x10, #1
    b    ct_loop

ct_done:
    ldp  x29, x30, [sp], #16
    ret

// =============================================================================
// copy_str — copia un string ASCIIZ
// =============================================================================
copy_str:
    ldrb w2, [x0]
    cbz  w2, copy_str_done
    strb w2, [x1]
    add  x0, x0, #1
    add  x1, x1, #1
    b    copy_str
copy_str_done:
    mov  x0, x1
    ret