// ========================================================================
// MÓDULO 2: VARIANZA Y DESVIACIÓN ESTÁNDAR (ARM64)
// Calcula la media, varianza y desviación estándar de 30 lecturas de
// temperatura del archivo lecturas.csv (columna TEMP)
// ========================================================================

.global _start

// ========================================================================
// Símbolos externos de utils.s
// ========================================================================
.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

// ========================================================================
// CONSTANTES DEL PROGRAMA
// ========================================================================
.equ N_VALUES,30

// ========================================================================
// SECCIÓN .rodata: STRINGS CONSTANTES
// ========================================================================
.section .rodata

archivo_salida:   .asciz "results/resultado_varianza.txt"

label_module:     .asciz "MODULE=VARIANCE"
label_total:      .asciz "TOTAL_VALUES="
label_med:        .asciz "MEAN="
label_var:        .asciz "VARIANCE="
label_desv:       .asciz "STD_DEV="
newline:          .asciz "\n"

// ========================================================================
// SECCIÓN .bss: VARIABLES EN MEMORIA
// ========================================================================
.section .bss
.align 8

array_temperaturas:     .space 30 * 8
buffer_salida:          .space 512

// ========================================================================
// SECCIÓN .text: CÓDIGO EJECUTABLE
// ========================================================================
.section .text

_start:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // ---- 1) Abrir lecturas.csv ----
    bl   utils_open_csv
    mov  x19, x0

    // ---- 2) Leer columna 1 (TEMP) en array_temperaturas ----
    mov  x0, x19
    mov  x1, #1
    adr  x2, array_temperaturas
    bl   utils_read_int_column
    cmp  x0, #N_VALUES
    b.ne error_exit

    // ---- 3) Cerrar archivo ----
    mov  x0, x19
    bl   utils_close_csv

    // ---- 4) Calcular media ----
    adr  x0, array_temperaturas
    bl   calcular_media
    mov  x19, x0

    // ---- 5) Calcular varianza ----
    adr  x0, array_temperaturas
    mov  x1, x19
    bl   calcular_varianza
    mov  x22, x0

    // ---- 6) Calcular desviación estándar ----
    mov  x0, x22
    bl   isqrt
    mov  x23, x0

    // ---- 7) Construir texto de salida ----
    adr  x24, buffer_salida

    // MODULE=VARIANCE
    adr  x0, label_module
    mov  x1, x24
    bl   copy_str
    mov  x24, x0
    adr  x0, newline
    mov  x1, x24
    bl   copy_str
    mov  x24, x0

    // TOTAL_VALUES=30
    adr  x0, label_total
    mov  x1, x24
    bl   copy_str
    mov  x24, x0
    mov  x0, #N_VALUES
    mov  x1, x24
    bl   utils_i64_to_str
    mov  x24, x0
    adr  x0, newline
    mov  x1, x24
    bl   copy_str
    mov  x24, x0

    // MEAN=X
    adr  x0, label_med
    mov  x1, x24
    bl   copy_str
    mov  x24, x0
    mov  x0, x19
    mov  x1, x24
    bl   utils_i64_to_str
    mov  x24, x0
    adr  x0, newline
    mov  x1, x24
    bl   copy_str
    mov  x24, x0

    // VARIANCE=X
    adr  x0, label_var
    mov  x1, x24
    bl   copy_str
    mov  x24, x0
    mov  x0, x22
    mov  x1, x24
    bl   utils_i64_to_str
    mov  x24, x0
    adr  x0, newline
    mov  x1, x24
    bl   copy_str
    mov  x24, x0

    // STD_DEV=X
    adr  x0, label_desv
    mov  x1, x24
    bl   copy_str
    mov  x24, x0
    mov  x0, x23
    mov  x1, x24
    bl   utils_i64_to_str
    mov  x24, x0
    adr  x0, newline
    mov  x1, x24
    bl   copy_str
    mov  x24, x0

    // ---- 8) Escribir archivo de resultados ----
    adr  x10, buffer_salida
    sub  x2, x24, x10
    adr  x0, archivo_salida
    adr  x1, buffer_salida
    bl   utils_write_result

    // ---- 9) Salir ----
    mov  x0, #0
    bl   utils_exit

error_exit:
    mov  x0, #1
    bl   utils_exit

// ========================================================================
// FUNCIÓN: calcular_media
// ========================================================================
calcular_media:
    stp x29, x30, [sp, #-16]!

    mov x1, #0
    mov x2, #0
    mov x3, x0

.mean_sum_loop:
    cmp x2, #N_VALUES
    bge .mean_divide

    ldr x4, [x3]
    add x1, x1, x4
    add x3, x3, #8
    add x2, x2, #1
    b .mean_sum_loop

.mean_divide:
    mov x0, x1
    mov x1, #N_VALUES
    sdiv x0, x0, x1

    ldp x29, x30, [sp], #16
    ret

// ========================================================================
// FUNCIÓN: calcular_varianza
// ========================================================================
calcular_varianza:
    stp x29, x30, [sp, #-16]!

    mov x2, #0
    mov x3, #0
    mov x4, x0
    mov x5, x1

.var_sum_loop:
    cmp x3, #N_VALUES
    bge .var_divide

    ldr x6, [x4]
    sub x6, x6, x5
    mul x6, x6, x6
    add x2, x2, x6

    add x4, x4, #8
    add x3, x3, #1
    b .var_sum_loop

.var_divide:
    mov x0, x2
    mov x1, #N_VALUES
    sdiv x0, x0, x1

    ldp x29, x30, [sp], #16
    ret

// ========================================================================
// FUNCIÓN: isqrt
// ========================================================================
isqrt:
    stp x29, x30, [sp, #-16]!

    cmp x0, #0
    beq .isqrt_return
    cmp x0, #1
    beq .isqrt_return

    mov x3, x0
    mov x1, x0

.isqrt_iter:
    sdiv x2, x3, x1
    add x2, x2, x1
    lsr x2, x2, #1

    cmp x2, x1
    bge .isqrt_converged

    mov x1, x2
    b .isqrt_iter

.isqrt_converged:
    mov x0, x1

.isqrt_return:
    ldp x29, x30, [sp], #16
    ret

// ========================================================================
// FUNCIÓN: copy_str
// ========================================================================
copy_str:
    ldrb w2, [x0]
    cbz  w2, .copy_done
    strb w2, [x1]
    add  x0, x0, #1
    add  x1, x1, #1
    b    copy_str
.copy_done:
    mov  x0, x1
    ret