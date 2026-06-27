.global _start

.extern utils_parse_i64
.extern utils_validate_range
.extern utils_validate_column
.extern utils_read_int_column
.extern utils_i64_to_str
.extern utils_write_result
.extern utils_exit

.equ MAX_VALUES, 100

.data
out_path: .asciz "results/resultado_media.txt"
lbl_calc: .asciz "CALC=WEIGHTED_MEAN\n"
lbl_col:  .asciz "COLUMN="
lbl_ws:   .asciz "WINDOW_START="
lbl_we:   .asciz "WINDOW_END="
lbl_cnt:  .asciz "COUNT="
lbl_sumx: .asciz "SUM_X="
lbl_wsum: .asciz "WEIGHT_SUM="
lbl_mean: .asciz "MEAN="
lbl_ok:   .asciz "STATUS=OK\n"
nl:       .asciz "\n"

msg_err_argc: .ascii "STATUS=ERROR\nERROR=INVALID_ARGS\nDETAIL=EXPECTED_4_ARGS\n"
len_err_argc = . - msg_err_argc
msg_err_rng: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=START_END_INVALID\n"
len_err_rng = . - msg_err_rng
msg_err_col: .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_MUST_BE_1_TO_6\n"
len_err_col = . - msg_err_col
msg_err_opn: .ascii "STATUS=ERROR\nERROR=FILE_NOT_FOUND\nDETAIL=COULD_NOT_OPEN_FILE\n"
len_err_opn = . - msg_err_opn

col_temp: .asciz "TEMP"
col_hum:  .asciz "HUM_AIRE"
col_s1:   .asciz "SOIL1"
col_s2:   .asciz "SOIL2"
col_luz:  .asciz "LUZ"
col_gas:  .asciz "GAS"
col_names: .quad col_temp, col_hum, col_s1, col_s2, col_luz, col_gas

.bss
values_buf: .skip 8 * MAX_VALUES
out_buf:    .skip 256

.text
_start:
    // leer argc y validar que vengan 4 argumentos (path, inicio, fin, columna)
    ldr x0, [sp]
    cmp x0, #5
    blt error_argc

    // parsear argumentos: x19=path, x20=inicio, x21=fin, x22=columna
    ldr x19, [sp, #16] // path del csv
    ldr x0, [sp, #24]
    bl utils_parse_i64
    mov x20, x0 // fila inicio

    ldr x0, [sp, #32]
    bl utils_parse_i64
    mov x21, x0 // fila fin

    ldr x0, [sp, #40]
    bl utils_parse_i64
    mov x22, x0 // columna

    // validar rango y columna
    mov x0, x20
    mov x1, x21
    bl utils_validate_range
    cbnz x0, error_range

    mov x0, x22
    bl utils_validate_column
    cbnz x0, error_column

    // abrir csv
    mov x0, #-100 // AT_FDCWD
    mov x1, x19
    mov x2, #0 // O_RDONLY
    mov x3, #0
    mov x8, #56 // openat
    svc #0
    cmp x0, #0
    blt error_open

    // leer columna del csv en values_buf
    mov x23, x0 // fd
    mov x0, x23
    mov x1, x22
    ldr x2, =values_buf
    mov x3, x20
    mov x4, x21
    bl utils_read_int_column
    mov x24, x0 // cantidad de valores leidos

    // cerrar csv
    mov x0, x23
    mov x8, #57 // close
    svc #0

    // calcular suma simple y media ponderada
    ldr x0, =values_buf
    mov x1, x24
    bl sum_values
    mov x25, x0 // suma simple

    ldr x0, =values_buf
    mov x1, x24
    bl weighted_mean
    mov x27, x0 // media ponderada

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
    sub x0, x22, #1
    ldr x1, =col_names
    ldr x0, [x1, x0, lsl #3]
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
    mov x0, x24
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_sumx
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

    // weight_sum = n*(n+1)/2
    add x0, x24, #1
    mul x0, x24, x0
    mov x1, #2
    sdiv x26, x0, x1

    ldr x0, =lbl_wsum
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

    ldr x0, =lbl_mean
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

// errores
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

// sum_values(ptr, count)
sum_values:
    mov x5, x0 // ptr
    mov x6, x1 // contador
    mov x2, #0 // indice
    mov x3, #0 // acumulador

sum_loop:
    cbz x6, sum_done
    ldr x4, [x5, x2, lsl #3] // leer values_buf[i]
    add x3, x3, x4
    add x2, x2, #1
    sub x6, x6, #1
    b sum_loop

sum_done:
    mov x0, x3
    ret

// weighted_mean(ptr, count)
weighted_mean:
    mov x5, x0 // ptr
    mov x6, x1 // contador
    mov x2, #0 // indice
    mov x3, #0 // acumulador ponderado

wm_loop:
    cbz x6, wm_done
    ldr x4, [x5, x2, lsl #3] // leer values_buf[i]
    add x7, x2, #1 // peso = i+1
    mul x4, x4, x7 // valor * peso
    add x3, x3, x4
    add x2, x2, #1
    sub x6, x6, #1
    b wm_loop

wm_done:
    // dividir entre weight_sum = n*(n+1)/2
    mov x4, x1
    add x7, x4, #1
    mul x7, x4, x7
    mov x8, #2
    sdiv x7, x7, x8
    sdiv x0, x3, x7
    ret

// copia string
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
