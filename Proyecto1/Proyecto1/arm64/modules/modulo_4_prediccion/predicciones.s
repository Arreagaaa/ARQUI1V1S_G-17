// =============================================================================
// predicciones.s — Módulo 4: Predicción lineal simple
// Integrante 4 — Grupo 17 — ACYE1 Invernadero Inteligente IoT
// =============================================================================
// Lee la columna HUM_SUELO_2 (índice 4) del archivo lecturas.csv (30 datos),
// calcula la predicción simple con punto fijo ×100 y escribe el resultado en
// results/resultado_prediccion.txt.
//
// Columnas del CSV (0-based):
//   0=ID  1=TEMP  2=HUM_AIRE  3=HUM_SUELO_1  4=HUM_SUELO_2
//
// Fórmulas (enunciado §10.4):
//   TOTAL_DIFF    = FINAL_VALUE - INITIAL_VALUE
//   AVG_CHANGE_FP = (TOTAL_DIFF * 100) / 29        ← centésimas con signo
//   NEXT_VALUE_FP = FINAL_VALUE * 100 + AVG_CHANGE_FP ← centésimas con signo
//
// Salida esperada:
//   MODULE=PREDICTION
//   TOTAL_VALUES=30
//   INITIAL_VALUE=48
//   FINAL_VALUE=35
//   TOTAL_DIFF=-13
//   AVG_CHANGE=-0.44
//   NEXT_VALUE=34.56
//
// Biblioteca usada: utils.s (compañero, branch main)
//   Funciones utilizadas:
//     utils_open_csv()                    → fd en x0
//     utils_read_int_column(fd, col, buf) → cantidad leída en x0
//     utils_close_csv(fd)
//     utils_write_result(path, buf, len)
//     utils_i64_to_str(val, buf)          → ptr siguiente byte en x0
//     utils_exit(code)
//
//   Subrutinas propias (§9.3 #10 — al menos una subrutina propia):
//     format_fixed_point  — convierte centésimas con signo a "entero.decimal"
//     int_to_ascii_signed — convierte entero con signo a ASCII
//     copy_str            — copia string ASCIIZ al buffer de salida
//
// Compilar y ejecutar:
//   cd Proyecto1/arm64
//   make modulo4
//   make run4
//
// Depuración con GDB:
//   Terminal 1: qemu-aarch64 -g 1234 build/modulo_4_prediccion
//   Terminal 2: gdb-multiarch build/modulo_4_prediccion
//     (gdb) set architecture aarch64
//     (gdb) target remote :1234
//     (gdb) break _start
//     (gdb) continue
// =============================================================================

// ---------------------------------------------------------------------------
// Constantes
// ---------------------------------------------------------------------------
.equ N_VALUES,   30
.equ N_MINUS_1,  29

// ---------------------------------------------------------------------------
// Símbolos externos de utils.s
// ---------------------------------------------------------------------------
.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit
.extern utils_read_column_config

// =============================================================================
// .rodata — strings de solo lectura
// =============================================================================
.section .rodata
.align 3

out_path:    .asciz "results/resultado_prediccion.txt"

lbl_module:  .asciz "MODULE=PREDICTION\n"
lbl_total:   .asciz "TOTAL_VALUES=30\n"
lbl_init:    .asciz "INITIAL_VALUE="
lbl_final:   .asciz "FINAL_VALUE="
lbl_diff:    .asciz "TOTAL_DIFF="
lbl_avg:     .asciz "AVG_CHANGE="
lbl_next:    .asciz "NEXT_VALUE="
nl:          .asciz "\n"

// =============================================================================
// .bss — buffers propios del módulo
// =============================================================================
.section .bss
.align 3

values_buf:  .skip 8 * N_VALUES   // arreglo propio para los 30 valores
out_buf:     .skip 512            // buffer de texto de salida completo

// =============================================================================
// .text — código
// =============================================================================
.section .text
.global _start

// ---------------------------------------------------------------------------
// _start — punto de entrada
//
// Registros callee-saved:
//   x19 = fd del CSV (entrada)
//   x20 = INITIAL_VALUE = values_buf[0]
//   x21 = FINAL_VALUE   = values_buf[29]
//   x22 = TOTAL_DIFF    = final - initial  (puede ser negativo)
//   x23 = AVG_CHANGE_FP = (TOTAL_DIFF * 100) / 29  (centésimas, puede negativo)
//   x24 = NEXT_VALUE_FP = FINAL*100 + AVG_CHANGE_FP (centésimas, puede negativo)
//   x25 = cursor en out_buf al construir la salida
// ---------------------------------------------------------------------------
_start:

    // ---- 1) Abrir lecturas.csv ----
    bl   utils_open_csv        // utils_open_csv() → fd en x0
    mov  x19, x0               // x19 = fd de entrada

    // utils_read_int_column(x0=fd, x1=col, x2=buf)
    // Salta el header internamente, llena buf con 30 enteros de 8 bytes.
    mov  x0, #4
    bl   utils_read_column_config
    mov  x1, x0
    mov  x0, x19
    adr  x2, values_buf
    bl   utils_read_int_column

    // Verificar que se leyeron exactamente 30 valores
    cmp  x0, #N_VALUES
    b.ne error_exit

    // ---- 3) Cerrar el CSV ----
    mov  x0, x19
    bl   utils_close_csv

    // ---- 4) Cargar initial y final ----
    adr  x9, values_buf
    ldr  x20, [x9]             // x20 = values_buf[0]  = INITIAL_VALUE
    ldr  x21, [x9, #(29*8)]    // x21 = values_buf[29] = FINAL_VALUE

    // ---- 5a) TOTAL_DIFF = FINAL - INITIAL ----
    sub  x22, x21, x20         // x22 = TOTAL_DIFF (negativo si baja)

    // ---- 5b) AVG_CHANGE_FP = (TOTAL_DIFF * 100) / 29 ----
    // Multiplicar por 100 antes de dividir conserva 2 decimales.
    // sdiv respeta el signo: (-1300)/29 = -44
    mov  x0, #100
    mul  x23, x22, x0          // x23 = TOTAL_DIFF * 100
    mov  x1, #N_MINUS_1
    sdiv x23, x23, x1          // x23 = AVG_CHANGE_FP (centésimas con signo)

    // ---- 5c) NEXT_VALUE_FP = FINAL*100 + AVG_CHANGE_FP ----
    mov  x0, #100
    mul  x24, x21, x0          // x24 = FINAL * 100
    add  x24, x24, x23         // x24 = NEXT_VALUE_FP (centésimas con signo)

    // ---- 6) Construir el buffer de salida ----
    adr  x25, out_buf          // x25 = cursor en out_buf

    // "MODULE=PREDICTION\n"
    adr  x0, lbl_module
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    // "TOTAL_VALUES=30\n"
    adr  x0, lbl_total
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    // "INITIAL_VALUE=<x20>\n"
    adr  x0, lbl_init
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    mov  x0, x20
    mov  x1, x25
    bl   utils_i64_to_str
    mov  x25, x0

    adr  x0, nl
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    // "FINAL_VALUE=<x21>\n"
    adr  x0, lbl_final
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    mov  x0, x21
    mov  x1, x25
    bl   utils_i64_to_str
    mov  x25, x0

    adr  x0, nl
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    // "TOTAL_DIFF=<x22>\n"  — puede ser negativo: usa int_to_ascii_signed
    adr  x0, lbl_diff
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    mov  x0, x22
    mov  x1, x25
    bl   int_to_ascii_signed
    mov  x25, x0

    adr  x0, nl
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    // "AVG_CHANGE=<x23 en centésimas>\n"  — ej: -44 → "-0.44"
    adr  x0, lbl_avg
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    mov  x0, x23
    mov  x1, x25
    bl   format_fixed_point
    mov  x25, x0

    adr  x0, nl
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    // "NEXT_VALUE=<x24 en centésimas>\n"  — ej: 3456 → "34.56"
    adr  x0, lbl_next
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    mov  x0, x24
    mov  x1, x25
    bl   format_fixed_point
    mov  x25, x0

    adr  x0, nl
    mov  x1, x25
    bl   copy_str
    mov  x25, x0

    // ---- 7) Escribir archivo de resultados ----
    // utils_write_result(x0=path, x1=buf, x2=len)
    adr  x10, out_buf
    sub  x2, x25, x10          // x2 = longitud total escrita
    adr  x0, out_path
    adr  x1, out_buf
    bl   utils_write_result

    // ---- 8) Salir con éxito ----
    mov  x0, #0
    bl   utils_exit

// ---------------------------------------------------------------------------
// error_exit
// ---------------------------------------------------------------------------
error_exit:
    mov  x0, #1
    bl   utils_exit

// =============================================================================
// int_to_ascii_signed — SUBRUTINA PROPIA (§9.3 #10)
// -----------------------------------------------------------------------------
// Convierte un entero de 64 bits con signo a su representación ASCII.
// Llama a utils_i64_to_str para la parte numérica.
//
// Entrada:
//   x0 = valor entero con signo
//   x1 = puntero al buffer destino
// Salida:
//   x0 = puntero al siguiente byte libre
// =============================================================================
int_to_ascii_signed:
    stp  x29, x30, [sp, #-32]!
    stp  x19, x20, [sp, #16]
    mov  x29, sp

    mov  x19, x0
    mov  x20, x1

    cmp  x19, #0
    b.ge ias_positive

    mov  w2, #'-'
    strb w2, [x20]
    add  x20, x20, #1
    neg  x19, x19

ias_positive:
    mov  x0, x19
    mov  x1, x20
    bl   utils_i64_to_str

    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

// =============================================================================
// format_fixed_point — SUBRUTINA PROPIA (§9.3 #10)
// -----------------------------------------------------------------------------
// Convierte un valor en centésimas con signo a "entero.decimal" con 2 dígitos.
//
// Entrada:
//   x0 = valor en centésimas con signo
//   x1 = puntero al buffer destino
// Salida:
//   x0 = puntero al siguiente byte libre
// =============================================================================
format_fixed_point:
    stp  x29, x30, [sp, #-48]!
    stp  x19, x20, [sp, #16]
    stp  x21, x22, [sp, #32]
    mov  x29, sp

    mov  x19, x0
    mov  x20, x1

    cmp  x19, #0
    b.ge ffp_positive

    mov  w0, #'-'
    strb w0, [x20]
    add  x20, x20, #1
    neg  x19, x19

ffp_positive:
    mov  x21, #100
    udiv x22, x19, x21
    msub x19, x22, x21, x19

    mov  x0, x22
    mov  x1, x20
    bl   utils_i64_to_str
    mov  x20, x0

    mov  w0, #'.'
    strb w0, [x20]
    add  x20, x20, #1

    cmp  x19, #10
    b.ge ffp_two_digits
    mov  w0, #'0'
    strb w0, [x20]
    add  x20, x20, #1

ffp_two_digits:
    mov  x0, x19
    mov  x1, x20
    bl   utils_i64_to_str
    mov  x20, x0

    mov  x0, x20

    ldp  x21, x22, [sp, #32]
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #48
    ret

// =============================================================================
// copy_str — copia un string ASCIIZ al buffer de salida
// -----------------------------------------------------------------------------
// Entrada:
//   x0 = puntero al string origen (terminado en NUL)
//   x1 = puntero al buffer destino
// Salida:
//   x0 = puntero al byte NUL copiado (siguiente byte libre)
// =============================================================================
copy_str:
copy_str_loop:
    ldrb w2, [x0]
    cbz  w2, copy_str_done
    strb w2, [x1]
    add  x0, x0, #1
    add  x1, x1, #1
    b    copy_str_loop
copy_str_done:
    mov  x0, x1
    ret