.global _start

.extern utils_parse_i64
.extern utils_validate_range
.extern utils_validate_column
.extern utils_read_int_column
.extern utils_count_lines
.include "sqrt.s"
.include "utils/print_uint.s"

.equ MAX_VALUES, 100

.data

// etiquetas de salida
lbl_calc: .ascii "CALC=RMSE\n";     len_calc = . - lbl_calc
lbl_col: .ascii "COLUMN=";          len_col = . - lbl_col
lbl_ws: .ascii "WINDOW_START=";     len_ws = . - lbl_ws
lbl_we: .ascii "WINDOW_END=";       len_we = . - lbl_we
lbl_cnt: .ascii "COUNT=";           len_cnt = . - lbl_cnt
lbl_ideal: .ascii "IDEAL=";         len_ideal = . - lbl_ideal
lbl_sse: .ascii "SUM_SQUARED_ERROR="; len_sse = . - lbl_sse
lbl_mse: .ascii "MSE=";            len_mse = . - lbl_mse
lbl_rmse: .ascii "RMSE=";          len_rmse = . - lbl_rmse
lbl_ok: .ascii "STATUS=OK\n";      len_ok = . - lbl_ok
newline: .ascii "\n"
minus_sign: .ascii "-"

col_temp: .asciz "TEMP"
col_hum:  .asciz "HUM_AIRE"
col_s1:   .asciz "SOIL1"
col_s2:   .asciz "SOIL2"
col_luz:  .asciz "LUZ"
col_gas:  .asciz "GAS"
col_names: .quad col_temp, col_hum, col_s1, col_s2, col_luz, col_gas

// mensajes de error
msg_err_argc: .ascii "STATUS=ERROR\nERROR=INVALID_ARGS\nDETAIL=EXPECTED_5_ARGS\n"
len_err_argc = . - msg_err_argc
msg_err_rng: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=START_END_INVALID\n"
len_err_rng = . - msg_err_rng
msg_err_col: .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_MUST_BE_1_TO_6\n"
len_err_col = . - msg_err_col
msg_err_opn: .ascii "STATUS=ERROR\nERROR=FILE_NOT_FOUND\nDETAIL=COULD_NOT_OPEN_FILE\n"
len_err_opn = . - msg_err_opn
msg_err_start: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=START_LINE_MUST_BE_AT_LEAST_1\n"
len_err_start = . - msg_err_start
msg_err_eof: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=END_LINE_EXCEEDS_FILE_LENGTH\n"
len_err_eof = . - msg_err_eof
msg_err_data: .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=RMSE_REQUIRES_AT_LEAST_2_VALUES\n"
len_err_data = . - msg_err_data

.bss
values_buf: .skip 8 * MAX_VALUES
num_buffer: .skip 32

.text
_start:
    // validar argumentos
    ldr x0, [sp]
    cmp x0, #6
    blt error_argc

    // parsear argumentos: x19=path, x20=inicio, x21=fin, x22=columna, x23=ideal
    ldr x19, [sp, #16]
    ldr x0, [sp, #24]
    bl utils_parse_i64
    mov x20, x0
    cmp x20, #1
    blt error_start

    ldr x0, [sp, #32]
    bl utils_parse_i64
    mov x21, x0

    ldr x0, [sp, #40]
    bl utils_parse_i64
    mov x22, x0

    ldr x0, [sp, #48]
    bl utils_parse_i64
    mov x23, x0

    // validar rango y columna
    mov x0, x20
    mov x1, x21
    bl utils_validate_range
    cbnz x0, error_range

    mov x0, x22
    bl utils_validate_column
    cbnz x0, error_column

    // abrir csv para contar lineas
    mov x0, #-100
    mov x1, x19
    mov x2, #0
    mov x8, #56
    svc #0
    cmp x0, #0
    blt error_open

    mov x24, x0
    bl utils_count_lines
    mov x26, x0

    // cerrar csv
    mov x0, x24
    mov x8, #57
    svc #0

    // validar que fin no exceda el archivo
    cmp x21, x26
    bgt error_eof

    // reabrir csv para leer datos
    mov x0, #-100
    mov x1, x19
    mov x2, #0
    mov x8, #56
    svc #0
    cmp x0, #0
    blt error_open

    // leer columna del csv
    mov x24, x0
    mov x0, x24
    mov x1, x22
    ldr x2, =values_buf
    mov x3, x20
    mov x4, x21
    bl utils_read_int_column
    mov x25, x0

    // cerrar csv
    mov x0, x24
    mov x8, #57
    svc #0

    // validar datos suficientes
    cmp x25, #2
    blt error_data

    // calcular rmse
    ldr x0, =values_buf
    mov x1, x25
    mov x2, x23
    bl rmse_calc
    mov x26, x0
    mov x27, x1
    mov x28, x2

    // imprimir resultados
    mov x0, #1
    ldr x1, =lbl_calc
    mov x2, len_calc
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =lbl_col
    mov x2, len_col
    mov x8, #64
    svc #0
    sub x0, x22, #1
    ldr x1, =col_names
    ldr x1, [x1, x0, lsl #3]
    mov x0, #1
    bl write_str
    mov x0, #1
    ldr x1, =newline
    mov x2, #1
    mov x8, #64
    svc #0

    mov x0, #1
    ldr x1, =lbl_ws
    mov x2, len_ws
    mov x8, #64
    svc #0
    mov x0, x20
    bl print_uint

    mov x0, #1
    ldr x1, =lbl_we
    mov x2, len_we
    mov x8, #64
    svc #0
    mov x0, x21
    bl print_uint

    mov x0, #1
    ldr x1, =lbl_cnt
    mov x2, len_cnt
    mov x8, #64
    svc #0
    mov x0, x25
    bl print_uint

    mov x0, #1
    ldr x1, =lbl_ideal
    mov x2, len_ideal
    mov x8, #64
    svc #0
    mov x0, x23
    bl print_uint

    mov x0, #1
    ldr x1, =lbl_sse
    mov x2, len_sse
    mov x8, #64
    svc #0
    mov x0, x26
    bl print_uint

    mov x0, #1
    ldr x1, =lbl_mse
    mov x2, len_mse
    mov x8, #64
    svc #0
    mov x0, x27
    bl print_uint

    mov x0, #1
    ldr x1, =lbl_rmse
    mov x2, len_rmse
    mov x8, #64
    svc #0
    mov x0, x28
    bl print_uint

    mov x0, #1
    ldr x1, =lbl_ok
    mov x2, len_ok
    mov x8, #64
    svc #0

    // salir ok
    mov x0, #0
    mov x8, #93
    svc #0

// write_str(x0=fd, x1=str) -> escribe string .asciz a stdout
write_str:
    stp x29, x30, [sp, #-16]!
    mov x5, x1
    mov x6, #0
ws_len:
    ldrb w7, [x5, x6]
    cbz w7, ws_write
    add x6, x6, #1
    b ws_len
ws_write:
    mov x2, x6
    mov x8, #64
    svc #0
    ldp x29, x30, [sp], #16
    ret

// errores
error_argc:
    ldr x1, =msg_err_argc
    mov x2, len_err_argc
    b error_exit

error_range:
    ldr x1, =msg_err_rng
    mov x2, len_err_rng
    b error_exit

error_column:
    ldr x1, =msg_err_col
    mov x2, len_err_col
    b error_exit

error_open:
    ldr x1, =msg_err_opn
    mov x2, len_err_opn
    b error_exit

error_start:
    ldr x1, =msg_err_start
    mov x2, len_err_start
    b error_exit

error_eof:
    ldr x1, =msg_err_eof
    mov x2, len_err_eof
    b error_exit

error_data:
    ldr x1, =msg_err_data
    mov x2, len_err_data

error_exit:
    mov x0, #1
    mov x8, #64
    svc #0
    mov x0, #1
    mov x8, #93
    svc #0

// calcula sse, mse y rmse
rmse_calc:
    stp x29, x30, [sp, #-16]!
    mov x5, x0
    mov x6, x1
    mov x7, x2
    mov x3, #0
    mov x4, #0

rmse_loop:
    cbz x6, rmse_done
    ldr x8, [x5, x3, lsl #3]
    sub x8, x8, x7
    mul x8, x8, x8
    add x4, x4, x8
    add x3, x3, #1
    sub x6, x6, #1
    b rmse_loop

rmse_done:
    sdiv x1, x4, x1
    mov x7, x1
    mov x0, x7
    bl int_sqrt
    mov x2, x0
    mov x0, x4
    mov x1, x7
    ldp x29, x30, [sp], #16
    ret
