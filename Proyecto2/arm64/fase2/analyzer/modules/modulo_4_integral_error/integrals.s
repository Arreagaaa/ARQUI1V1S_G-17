// modulo_4_integral_error.s — Integrante 3 — Grupo 17
.equ MAX_VALUES, 1000

.extern utils_read_int_column
.extern utils_parse_i64
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit
.extern utils_validate_range
.extern utils_validate_column
.extern utils_count_lines


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

msg_err_argc:  .ascii "STATUS=ERROR\nERROR=INVALID_ARGS\nDETAIL=EXPECTED_PATH_START_END_COLUMN_IDEAL\n"
len_err_argc = . - msg_err_argc
msg_err_rng:   .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=START_END_INVALID\n"
len_err_rng = . - msg_err_rng
msg_err_col:   .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_MUST_BE_1_TO_6\n"
len_err_col = . - msg_err_col
msg_err_opn:   .ascii "STATUS=ERROR\nERROR=FILE_NOT_FOUND\nDETAIL=COULD_NOT_OPEN_FILE\n"
len_err_opn = . - msg_err_opn
msg_err_start: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=START_LINE_MUST_BE_AT_LEAST_1\n"
len_err_start = . - msg_err_start
msg_err_eof:   .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=END_LINE_EXCEEDS_FILE_LENGTH\n"
len_err_eof = . - msg_err_eof
msg_err_count: .ascii "STATUS=ERROR\nERROR=INVALID_COUNT\nDETAIL=RANGE_OUT_OF_FILE_OR_TOO_LARGE\n"
len_err_count = . - msg_err_count
msg_err_data:  .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=INTEGRAL_REQUIRES_AT_LEAST_2_VALUES\n"
len_err_data = . - msg_err_data

.section .bss
.align 3
values_buf:  .skip 8 * MAX_VALUES
out_buf:     .skip 512

.section .text
.global _start

_start:
    ldr  x0, [sp]
    cmp  x0, #6
    bge  parse_int_args
    b    error_argc
parse_int_args:

    // Extraer argumentos 
    ldr  x19, [sp, #16]     // path del archivo
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

    // Validar start >= 1
    cmp  x20, #1
    bge  int_range_ok
    b    error_start
int_range_ok:

    // Validar start <= end
    mov  x0, x20
    mov  x1, x21
    bl   utils_validate_range
    cbnz x0, error_range

    // Validar columna 1 a 6
    mov  x0, x22
    bl   utils_validate_column
    cbnz x0, error_column

    // Validar que el rango no pase MAX_VALUES
    sub  x26, x21, x20
    add  x26, x26, #1
    cmp  x26, #MAX_VALUES
    ble  int_count_ok
    b    error_count
int_count_ok:

    // Abrir archivo usando el path recibido
    mov  x0, #-100
    mov  x1, x19
    mov  x2, #0
    mov  x3, #0
    mov  x8, #56
    svc  #0
    cmp  x0, #0
    bge  int_open_ok
    b    error_open

int_open_ok:
    mov  x24, x0

    // Contar líneas reales del archivo
    mov  x0, x24
    bl   utils_count_lines
    mov  x25, x0

    mov  x0, x24
    bl   utils_close_csv

    // Validar que end exista dentro del archivo
    cmp  x21, x25
    ble  int_eof_ok
    b    error_eof
int_eof_ok:

    // Abrir de nuevo para leer los datos
    mov  x0, #-100
    mov  x1, x19
    mov  x2, #0
    mov  x3, #0
    mov  x8, #56
    svc  #0
    cmp  x0, #0
    bge  int_open2_ok
    b    error_open

int_open2_ok:
    mov  x24, x0

    mov  x0, x24
    mov  x1, x22
    ldr  x2, =values_buf
    mov  x3, x20
    mov  x4, x21
    bl   utils_read_int_column
    mov  x25, x0

    mov  x0, x24
    bl   utils_close_csv

    // Validar que leyó exactamente el rango solicitado
    sub  x26, x21, x20
    add  x26, x26, #1
    cmp  x25, x26
    beq  int_count_match
    b    error_count
int_count_match:

    // Integral por trapecio requiere mínimo 2 valores
    cmp  x25, #2
    bge  int_enough_data
    b    error_data
int_enough_data:

    // INTEGRAL DEL ERROR REGLA DEL TRAPECIO
  
    mov  x28, #0                 // AREA_ERROR = 0 (Acumulador total)
    mov  x10, #0                 // i = 0
    sub  x26, x25, #1            // Límite N - 1

    
    adr  x12, values_buf

ciclo_integral:
    cmp  x10, x26
    bge  fin_integral
    b    do_integral
do_integral:

    //CÁLCULO ERROR_i: |Y_i - IDEAL|
    ldr  x14, [x12, x10, lsl #3] // x14 = Dato actual (Y_i)
    subs x15, x14, x27           // x15 = Dato - IDEAL
    bge  abs1_ok                 // Si (Dato >= IDEAL), salta
    neg  x15, x15                // Si es negativo, lo vuelve absoluto
abs1_ok:

    //CÁLCULO ERROR_NEXT: |Y_next - IDEAL| 
    add  x11, x10, #1            // x11 = i + 1
    ldr  x16, [x12, x11, lsl #3] // x16 = Dato siguiente (Y_next)
    subs x17, x16, x27           // x17 = Dato siguiente - IDEAL
    bge  abs2_ok
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

error_argc:
    ldr  x1, =msg_err_argc
    mov  x2, len_err_argc
    b    error_exit

error_range:
    ldr  x1, =msg_err_rng
    mov  x2, len_err_rng
    b    error_exit

error_column:
    ldr  x1, =msg_err_col
    mov  x2, len_err_col
    b    error_exit

error_open:
    ldr  x1, =msg_err_opn
    mov  x2, len_err_opn
    b    error_exit

error_start:
    ldr  x1, =msg_err_start
    mov  x2, len_err_start
    b    error_exit

error_eof:
    ldr  x1, =msg_err_eof
    mov  x2, len_err_eof
    b    error_exit

error_count:
    ldr  x1, =msg_err_count
    mov  x2, len_err_count
    b    error_exit

error_data:
    ldr  x1, =msg_err_data
    mov  x2, len_err_data

error_exit:
    mov  x0, #1
    mov  x8, #64
    svc  #0

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

    