// modulo_4_integral_error.s — Integrante 3 — Grupo 17
.equ MAX_VALUES, 1000

.extern utils_open_csv
.extern utils_read_int_column
.extern utils_parse_i64
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

.section .rodata
.align 3
out_path:      .asciz "results/resultado_integral.txt"
lbl_calc:      .asciz "CALC=ERROR_INTEGRAL\n"
lbl_col:       .asciz "COLUMN="
lbl_win_start: .asciz "WINDOW_START="
lbl_win_end:   .asciz "WINDOW_END="
lbl_count:     .asciz "COUNT="
lbl_ideal:     .asciz "IDEAL="
lbl_err_int:   .asciz "ERROR_INTEGRAL="
lbl_status:    .asciz "STATUS=OK\n"
nl:            .asciz "\n"

.section .bss
.align 3
values_buf:  .skip 8 * MAX_VALUES
out_buf:     .skip 512

.section .text
.global _start

_start:
    ldr  x0, [sp]
    cmp  x0, #6
    blt  error_exit

    // Extraer argumentos 
    ldr  x20, [sp, #24]     // start
    ldr  x21, [sp, #32]     // end
    ldr  x22, [sp, #40]     // col
    ldr  x27, [sp, #48]     // ideal

    mov  x0, x20
    bl   utils_parse_i64
    mov  x20, x0

    mov  x0, x21
    bl   utils_parse_i64
    mov  x21, x0

    mov  x0, x22
    bl   utils_parse_i64
    mov  x22, x0

    mov  x0, x27
    bl   utils_parse_i64
    mov  x27, x0

    bl   utils_open_csv
    mov  x19, x0

    mov  x0, x19
    mov  x1, x22
    adr  x2, values_buf
    mov  x3, x20
    mov  x4, x21
    bl   utils_read_int_column
    
    cmp  x0, #0
    ble  error_exit
    mov  x25, x0

    mov  x0, x19
    bl   utils_close_csv

    // INTEGRAL DEL ERROR REGLA DEL TRAPECIO
  
    mov  x28, #0                 // AREA_ERROR = 0 (Acumulador total)
    mov  x10, #0                 // i = 0
    sub  x26, x25, #1            // Límite N - 1
    cmp  x26, #0
    ble  fin_integral            // Si hay 1 dato o menos termina
    
    adr  x12, values_buf

ciclo_integral:
    cmp  x10, x26
    b.ge fin_integral

    //CÁLCULO ERROR_i: |Y_i - IDEAL|
    ldr  x14, [x12, x10, lsl #3] // x14 = Dato actual (Y_i)
    subs x15, x14, x27           // x15 = Dato - IDEAL
    b.ge abs1_ok                 // Si (Dato >= IDEAL), salta
    neg  x15, x15                // Si es negativo, lo vuelve absoluto
abs1_ok:

    //CÁLCULO ERROR_NEXT: |Y_next - IDEAL| 
    add  x11, x10, #1            // x11 = i + 1
    ldr  x16, [x12, x11, lsl #3] // x16 = Dato siguiente (Y_next)
    subs x17, x16, x27           // x17 = Dato siguiente - IDEAL
    b.ge abs2_ok
    neg  x17, x17
abs2_ok:

    // CÁLCULO TRAPECIO Y ACUMULACIÓN 
    add  x18, x15, x17           // x18 = ERROR_i + ERROR_NEXT
    lsr  x18, x18, #1            // x18 = x18 / 2  (Área del trapecio)

    add  x28, x28, x18           // AREA_ERROR = AREA_ERROR + Área del trapecio

    add  x10, x10, #1            // i++
    b    ciclo_integral

fin_integral:

  
    // CONSTRUIR SALIDA
   
    adr  x29, out_buf
    
    adr  x0, lbl_calc
    mov  x1, x29
    bl   copy_str
    mov  x29, x0

    adr  x0, lbl_col
    mov  x1, x29
    bl   copy_str
    mov  x29, x0
    mov  x0, x22
    mov  x1, x29
    bl   utils_i64_to_str
    mov  x29, x0
    adr  x0, nl
    mov  x1, x29
    bl   copy_str
    mov  x29, x0

    adr  x0, lbl_win_start
    mov  x1, x29
    bl   copy_str
    mov  x29, x0
    mov  x0, x20
    mov  x1, x29
    bl   utils_i64_to_str
    mov  x29, x0
    adr  x0, nl
    mov  x1, x29
    bl   copy_str
    mov  x29, x0

    adr  x0, lbl_win_end
    mov  x1, x29
    bl   copy_str
    mov  x29, x0
    mov  x0, x21
    mov  x1, x29
    bl   utils_i64_to_str
    mov  x29, x0
    adr  x0, nl
    mov  x1, x29
    bl   copy_str
    mov  x29, x0

    adr  x0, lbl_count
    mov  x1, x29
    bl   copy_str
    mov  x29, x0
    mov  x0, x25
    mov  x1, x29
    bl   utils_i64_to_str
    mov  x29, x0
    adr  x0, nl
    mov  x1, x29
    bl   copy_str
    mov  x29, x0

    adr  x0, lbl_ideal
    mov  x1, x29
    bl   copy_str
    mov  x29, x0
    mov  x0, x27
    mov  x1, x29
    bl   utils_i64_to_str
    mov  x29, x0
    adr  x0, nl
    mov  x1, x29
    bl   copy_str
    mov  x29, x0

    adr  x0, lbl_err_int
    mov  x1, x29
    bl   copy_str
    mov  x29, x0
    mov  x0, x28
    mov  x1, x29
    bl   utils_i64_to_str
    mov  x29, x0
    adr  x0, nl
    mov  x1, x29
    bl   copy_str
    mov  x29, x0

    adr  x0, lbl_status
    mov  x1, x29
    bl   copy_str
    mov  x29, x0

    adr  x10, out_buf
    sub  x2, x29, x10
    adr  x0, out_path
    adr  x1, out_buf
    bl   utils_write_result

    mov  x0, #0
    bl   utils_exit

error_exit:
    mov  x0, #1
    bl   utils_exit

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