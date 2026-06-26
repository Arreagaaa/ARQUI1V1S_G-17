.global _start

.extern utils_parse_i64
.extern utils_validate_range
.extern utils_validate_column
.extern utils_read_int_column
.extern utils_count_lines
.extern utils_i64_to_str
.extern utils_write_result
.extern utils_exit

.equ MAX_VALUES, 100

.data
out_path: .asciz "results/resultado_rmse.txt"
lbl_calc: .asciz "CALC=RMSE\n"
lbl_col:  .asciz "COLUMN="
lbl_ws:   .asciz "WINDOW_START="
lbl_we:   .asciz "WINDOW_END="
lbl_cnt:  .asciz "COUNT="
lbl_ideal: .asciz "IDEAL="
lbl_sse:  .asciz "SUM_SQUARED_ERROR="
lbl_mse:  .asciz "MSE="
lbl_rmse: .asciz "RMSE="
lbl_ok:   .asciz "STATUS=OK\n"
nl:       .asciz "\n"

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

// nombres de columna para salida
col_names:
    .quad col_temp
    .quad col_hum
    .quad col_soil1
    .quad col_soil2
    .quad col_luz
    .quad col_gas

col_temp:   .asciz "TEMP"
col_hum:    .asciz "HUM_AIRE"
col_soil1:  .asciz "SOIL1"
col_soil2:  .asciz "SOIL2"
col_luz:    .asciz "LUZ"
col_gas:    .asciz "GAS"

.bss
values_buf: .skip 8 * MAX_VALUES
out_buf:    .skip 256

.text
_start:
    // leer argc y validar que vengan 5 argumentos (path, inicio, fin, columna, ideal)
    ldr x0, [sp]
    cmp x0, #6
    blt error_argc

    // parsear argumentos: x19=path, x20=inicio, x21=fin, x22=columna, x23=ideal
    ldr x19, [sp, #16] // path del csv
    ldr x0, [sp, #24]
    bl utils_parse_i64
    mov x20, x0 // fila inicio

    // validar que inicio sea >= 1
    cmp x20, #1
    blt error_start

    ldr x0, [sp, #32]
    bl utils_parse_i64
    mov x21, x0 // fila fin

    ldr x0, [sp, #40]
    bl utils_parse_i64
    mov x22, x0 // columna

    ldr x0, [sp, #48]
    bl utils_parse_i64
    mov x23, x0 // valor ideal

    // validar rango y columna
    mov x0, x20
    mov x1, x21
    bl utils_validate_range
    cbnz x0, error_range

    mov x0, x22
    bl utils_validate_column
    cbnz x0, error_column

    // abrir csv para contar lineas
    mov x0, #-100 // AT_FDCWD
    mov x1, x19
    mov x2, #0 // O_RDONLY
    mov x3, #0
    mov x8, #56 // openat
    svc #0
    cmp x0, #0
    blt error_open

    mov x24, x0 // fd

    // contar lineas (sin header)
    mov x0, x24
    bl utils_count_lines
    mov x26, x0 // total de lineas

    // cerrar csv temporal
    mov x0, x24
    mov x8, #57 // close
    svc #0

    // validar que fin no exceda el total de lineas
    cmp x21, x26
    bgt error_eof

    // reabrir csv para leer datos
    mov x0, #-100 // AT_FDCWD
    mov x1, x19
    mov x2, #0 // O_RDONLY
    mov x3, #0
    mov x8, #56 // openat
    svc #0
    cmp x0, #0
    blt error_open

    mov x24, x0 // fd

    // leer columna del csv en values_buf
    mov x0, x24
    mov x1, x22
    ldr x2, =values_buf
    mov x3, x20
    mov x4, x21
    bl utils_read_int_column
    mov x25, x0 // cantidad de valores leidos

    // cerrar csv
    mov x0, x24
    mov x8, #57 // close
    svc #0

    // validar que haya al menos 2 datos para RMSE
    cmp x25, #2
    blt error_data

    // calcular rmse
    ldr x0, =values_buf
    mov x1, x25
    mov x2, x23
    bl rmse_calc
    mov x26, x0 // suma errores al cuadrado
    mov x27, x1 // mse
    mov x28, x2 // rmse

    // armar buffer de salida con todas las etiquetas
    ldr x9, =out_buf

    ldr x0, =lbl_calc
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_col
    mov x1, x9
    bl copy_str
    mov x9, x0
    // buscar nombre de columna segun indice
    ldr x0, =col_names
    sub x1, x22, #1
    ldr x0, [x0, x1, lsl #3]
    mov x1, x9
    bl copy_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_ws
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x20
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_we
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x21
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_cnt
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x25
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_ideal
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x23
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_sse
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x26
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_mse
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x27
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_rmse
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x28
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_ok
    mov x1, x9
    bl copy_str
    mov x9, x0

    // escribir resultado al archivo
    ldr x10, =out_buf
    sub x2, x9, x10 // longitud = ptr_fin - ptr_inicio
    ldr x0, =out_path
    ldr x1, =out_buf
    bl utils_write_result

    mov x0, #0
    bl utils_exit

// manejo de errores, todos imprimen a stderr y salen con codigo 1
error_argc:
    mov x0, #1
    ldr x1, =msg_err_argc
    mov x2, len_err_argc
    mov x8, #64 // write
    svc #0
    mov x0, #1
    bl utils_exit

error_range:
    mov x0, #1
    ldr x1, =msg_err_rng
    mov x2, len_err_rng
    mov x8, #64 // write
    svc #0
    mov x0, #1
    bl utils_exit

error_column:
    mov x0, #1
    ldr x1, =msg_err_col
    mov x2, len_err_col
    mov x8, #64 // write
    svc #0
    mov x0, #1
    bl utils_exit

error_open:
    mov x0, #1
    ldr x1, =msg_err_opn
    mov x2, len_err_opn
    mov x8, #64 // write
    svc #0
    mov x0, #1
    bl utils_exit

error_start:
    mov x0, #1
    ldr x1, =msg_err_start
    mov x2, len_err_start
    mov x8, #64 // write
    svc #0
    mov x0, #1
    bl utils_exit

error_eof:
    mov x0, #1
    ldr x1, =msg_err_eof
    mov x2, len_err_eof
    mov x8, #64 // write
    svc #0
    mov x0, #1
    bl utils_exit

error_data:
    mov x0, #1
    ldr x1, =msg_err_data
    mov x2, len_err_data
    mov x8, #64 // write
    svc #0
    mov x0, #1
    bl utils_exit

// x0=ptr buffer, x1=count, x2=valor_ideal
// retorna: x0=sum_squared_errors, x1=mse, x2=rmse
rmse_calc:
    stp x29, x30, [sp, #-16]!
    mov x5, x0 // ptr
    mov x6, x1 // contador
    mov x7, x2 // ideal
    mov x3, #0 // indice
    mov x4, #0 // suma errores al cuadrado

rmse_loop:
    cbz x6, rmse_done
    ldr x8, [x5, x3, lsl #3] // values_buf[i]
    sub x8, x8, x7 // diff = valor - ideal
    mul x8, x8, x8 // diff^2
    add x4, x4, x8
    add x3, x3, #1
    sub x6, x6, #1
    b rmse_loop

rmse_done:
    sdiv x1, x4, x1 // mse = suma / count
    mov x7, x1       // guardar mse
    mov x0, x7
    bl int_sqrt     // x0 = sqrt(mse) = rmse
    mov x2, x0      // x2 = rmse
    mov x0, x4      // x0 = suma errores al cuadrado
    mov x1, x7      // x1 = mse
    ldp x29, x30, [sp], #16
    ret

// x0=numero, retorna raiz cuadrada entera en x0
int_sqrt:
    mov x1, #1
sqrt_loop:
    mul x2, x1, x1
    cmp x2, x0
    bgt sqrt_end
    add x1, x1, #1
    b sqrt_loop
sqrt_end:
    sub x0, x1, #1
    ret

// x0=src, x1=dst
// copia string hasta \0, retorna puntero al byte siguiente del ultimo char copiado
copy_str:
    ldrb w2, [x0]
    cbz w2, copy_end
    strb w2, [x1]
    add x0, x0, #1
    add x1, x1, #1
    b copy_str

copy_end:
    mov x0, x1
    ret
