// =============================================================================
// media.s — Módulo 1: Media aritmética ponderada
// Integrante 1 — Grupo 17 — ACYE1 Invernadero Inteligente IoT
// =============================================================================
// Lee la columna TEMP del archivo lecturas.csv (30 datos reales),
// calcula la media ponderada con pesos crecientes W_i = i  (1..30)
// y escribe el resultado en results/resultado_media.txt.
//
// Dependencias: utils.s (biblioteca común)
//   utils_open_csv, utils_read_int_column, utils_close_csv,
//   utils_write_result, utils_i64_to_str, utils_exit
//
// Fórmula (enunciado §10.1):
//     MEDIA_PONDERADA = Σ(X_i * W_i) / ΣW_i
//     con W_i = i   (i = 1..30)   y  ΣW_i = 465
//
// Formato exacto de salida (enunciado §10.1):
//     MODULE=WEIGHTED_MEAN
//     TOTAL_VALUES=30
//     SUM_X=<suma de X_i>
//     WEIGHT_SUM=465
//     WEIGHTED_MEAN=<media entera>
//
// Compilar y ejecutar:
//     cd Proyecto1/arm64
//     make utils
//     make modulo1
//     make run1
// =============================================================================

// =============================================================================
// Importar símbolos de utils.s
// =============================================================================
.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

// =============================================================================
// Constantes del módulo
// =============================================================================
.equ N_VALUES,        30
.equ WEIGHT_SUM,      465

// =============================================================================
// Strings de solo lectura
// =============================================================================
.section .rodata
.align 3

out_path:   .asciz "results/resultado_media.txt"
mod_name:   .asciz "MODULE=WEIGHTED_MEAN\n"
total_v:    .asciz "TOTAL_VALUES=30\n"
lbl_sumx:   .asciz "SUM_X="
lbl_wsum:   .asciz "WEIGHT_SUM=465\n"
lbl_mean:   .asciz "WEIGHTED_MEAN="
nl:         .asciz "\n"

// =============================================================================
// Buffers
// =============================================================================
.section .bss
.align 3

values_buf: .skip 8 * N_VALUES
out_buf:    .skip 256

// =============================================================================
// Código principal
// =============================================================================
.section .text
.global _start

// ---------------------------------------------------------------------------
// _start — punto de entrada
//   1. utils_open_csv            → fd
//   2. utils_read_int_column     → values_buf[30] (col 1 = TEMP)
//   3. utils_close_csv
//   4. sum_values (subrutina)    → sum_x
//   5. weighted_mean (propia)    → weighted_mean
//   6. Construir out_buf con formato de salida
//   7. utils_write_result        → results/resultado_media.txt
//   8. utils_exit(0)
//
// Registros persistentes:
//   x21 = sum_x
//   x22 = weighted_mean
//   x23 = longitud total del buffer de salida
//   x9  = cursor en out_buf (durante construcción)
// ---------------------------------------------------------------------------
_start:
    // ---- 1) Abrir lecturas.csv ----
    bl   utils_open_csv
    mov  x19, x0

    // ---- 2) Leer columna 1 (TEMP, índice 0-based = 1) ----
    mov  x0, x19
    mov  x1, #1
    adr  x2, values_buf
    bl   utils_read_int_column

    // ---- 3) Cerrar archivo ----
    mov  x0, x19
    bl   utils_close_csv

    // ---- 4) Calcular ΣX ----
    adr  x0, values_buf
    bl   sum_values
    mov  x21, x0

    // ---- 5) Calcular media ponderada (subrutina propia) ----
    adr  x0, values_buf
    bl   weighted_mean
    mov  x22, x0

    // ---- 6) Construir buffer de salida ----
    adr  x9, out_buf

    // "MODULE=WEIGHTED_MEAN\n"
    adr  x0, mod_name
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // "TOTAL_VALUES=30\n"
    adr  x0, total_v
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // "SUM_X="
    adr  x0, lbl_sumx
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x21
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    // "\n"
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // "WEIGHT_SUM=465\n"
    adr  x0, lbl_wsum
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // "WEIGHTED_MEAN="
    adr  x0, lbl_mean
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x22
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    // "\n"
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // ---- 7) Escribir archivo de resultados ----
    adr  x10, out_buf
    sub  x23, x9, x10

    adr  x0, out_path
    adr  x1, out_buf
    mov  x2, x23
    bl   utils_write_result

    // ---- 8) Salir ----
    mov  x0, #0
    bl   utils_exit

// =============================================================================
// sum_values — Σ de N_VALUES enteros con signo de 64 bits
// ---------------------------------------------------------------------------
// Entrada: x0 = puntero al arreglo
// Salida:  x0 = suma total
// =============================================================================
sum_values:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    mov  x1, x0
    mov  x2, #0
    mov  x3, #0
sum_loop:
    cmp  x2, #N_VALUES
    b.ge sum_done
    ldr  x4, [x1, x2, lsl #3]
    add  x3, x3, x4
    add  x2, x2, #1
    b    sum_loop
sum_done:
    mov  x0, x3
    ldp  x29, x30, [sp], #16
    ret

// =============================================================================
// weighted_mean — SUBRUTINA PROPIA (enunciado §9.3 #10)
// ---------------------------------------------------------------------------
// Calcula la media aritmética ponderada entera:
//   mean = Σ (X_i * (i+1)) / 465
//
// Entrada: x0 = puntero al arreglo de 30 enteros (8 bytes c/u)
// Salida:  x0 = media ponderada (división entera con truncamiento)
// =============================================================================
weighted_mean:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    mov  x1, x0
    mov  x2, #0
    mov  x3, #0
wm_loop:
    cmp  x2, #N_VALUES
    b.ge wm_done
    ldr  x4, [x1, x2, lsl #3]
    add  x5, x2, #1
    mul  x4, x4, x5
    add  x3, x3, x4
    add  x2, x2, #1
    b    wm_loop
wm_done:
    mov  x4, #WEIGHT_SUM
    sdiv x0, x3, x4
    ldp  x29, x30, [sp], #16
    ret

// =============================================================================
// copy_str — copia string ASCIIZ (src → dst)
// ---------------------------------------------------------------------------
// Entrada:
//   x0 = puntero al string fuente (NUL-terminated)
//   x1 = puntero al buffer destino
// Salida:
//   x0 = puntero al NUL en destino (siguiente byte libre)
// =============================================================================
copy_str:
    ldrb w2, [x0]
    cbz  w2, copy_done
    strb w2, [x1]
    add  x0, x0, #1
    add  x1, x1, #1
    b    copy_str
copy_done:
    mov  x0, x1
    ret
