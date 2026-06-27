.global _start

.extern utils_parse_i64
.extern utils_validate_range
.extern utils_validate_column
.extern utils_read_int_column
.extern utils_i64_to_str
.extern utils_write_result
.extern utils_exit

.equ MAX_VALUES, 100
.equ MIN_DATOS, 5
.equ VENTANA_REG, 5

.data
out_path:      .asciz "results/resultado_derivada_local.txt"


lbl_module:     .asciz "MODULE=LOCAL_DERIVATIVE\n"
lbl_calc:       .asciz "CALC=LOCAL_DERIVATIVE\n"
lbl_col:        .asciz "COLUMN="
lbl_ws:         .asciz "WINDOW_START="
lbl_we:         .asciz "WINDOW_END="
lbl_cnt:        .asciz "COUNT="
lbl_wsize:		.asciz "WINDOW_SIZE="
lbl_max:		.asciz "MAX_LOCAL_SLOPE_X100="
lbl_ok:			.asciz "STATUS=OK\n"
nl:				.asciz "\n"

msg_err_argc: .ascii "STATUS=ERROR\nERROR=INVALID_ARGS\nDETAIL=EXPECTED_4_ARGS\n"
len_err_argc = . - msg_err_argc
msg_err_rng: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=START_END_INVALID\n"
len_err_rng = . - msg_err_rng
msg_err_col: .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_MUST_BE_1_TO_6\n"
len_err_col = . - msg_err_col
msg_err_opn: .ascii "STATUS=ERROR\nERROR=FILE_NOT_FOUND\nDETAIL=COULD_NOT_OPEN_FILE\n"
len_err_opn = . - msg_err_opn
msg_err_few: .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=LOCAL_DERIVATIVE_REQUIRES_AT_LEAST_5_VALUES\n"
len_err_few = . - msg_err_few

.bss
values_buf:    .skip 8 * MAX_VALUES
out_buf:       .skip 512

.text

// Registros de larga vida:
//   x19 = fd              x26 = N (valores leidos)
//   x27 = columna         x28 = fila inicio
//   [sp, #0] = fila fin
// x20 = max slope, x25 = rango esperado, x26 = datos
// x27 = columna, x28 = inicio, [sp] = fin
_start:
    ldr  x0, [sp]
    cmp  x0, #5
    blt  error_argc

    ldr  x19, [sp, #16]

    ldr  x0, [sp, #24]
    bl   utils_parse_i64
    mov  x28, x0

    ldr  x0, [sp, #32]
    bl   utils_parse_i64
    sub  sp, sp, #16
    str  x0, [sp]

    ldr  x0, [sp, #56]
    bl   utils_parse_i64
    mov  x27, x0

    // validar rango
    mov  x0, x28
    ldr  x1, [sp]
    bl   utils_validate_range
    cbnz x0, error_range

    // validar columna
    mov  x0, x27
    bl   utils_validate_column
    cbnz x0, error_column

    // validar tamano del rango
    ldr  x25, [sp]
    sub  x25, x25, x28
    add  x25, x25, #1
    cmp  x25, #MAX_VALUES
    b.gt error_range

    // abrir csv
    mov  x0, #-100
    mov  x1, x19
    mov  x2, #0
    mov  x3, #0
    mov  x8, #56
    svc  #0
    cmp  x0, #0
    blt  error_open

    mov  x19, x0

    // leer columna del csv
    mov  x0, x19
    mov  x1, x27
    ldr  x2, =values_buf
    mov  x3, x28
    ldr  x4, [sp]
    bl   utils_read_int_column
    mov  x26, x0

    // cerrar csv
    mov  x0, x19
    mov  x8, #57
    svc  #0

    // validar que el rango exista
    cmp  x26, x25
    b.ne error_range

    // minimo para regresion local
    cmp  x26, #MIN_DATOS
    b.lt error_few_data

    // recorrer ventanas de 5 datos
    mov  x20, #0
    mov  x10, #0
    sub  x13, x26, #VENTANA_REG

local_loop:
    cmp  x10, x13
    b.gt local_done

    lsl  x11, x10, #3
    ldr  x12, =values_buf
    add  x12, x12, x11

    mov  x0, x12
    bl   calc_local_slope

    cmp  x0, #0
    b.ge slope_positive
    neg  x1, x0
    b    slope_check
slope_positive:
    mov  x1, x0

slope_check:
    cmp  x1, x20
    b.le slope_next
    mov  x20, x1

slope_next:
    add  x10, x10, #1
    b    local_loop

local_done:

    // construir salida
    ldr  x9, =out_buf

    ldr  x0, =lbl_calc
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    ldr  x0, =lbl_col
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x27
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    ldr  x0, =nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    ldr  x0, =lbl_ws
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x28
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    ldr  x0, =nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    ldr  x0, =lbl_we
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    ldr  x0, [sp]
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    ldr  x0, =nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    ldr  x0, =lbl_cnt
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x26
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    ldr  x0, =nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    ldr  x0, =lbl_wsize
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, #VENTANA_REG
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    ldr  x0, =nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    ldr  x0, =lbl_max
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x20
    mov  x1, x9
    bl   utils_i64_to_str
    mov  x9, x0
    ldr  x0, =nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    ldr  x0, =lbl_ok
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // escribir resultado
    ldr  x10, =out_buf
    sub  x2, x9, x10
    ldr  x0, =out_path
    ldr  x1, =out_buf
    bl   utils_write_result

    mov  x0, #0
    bl   utils_exit

// pendiente local de una ventana
// entrada: x0 = inicio de ventana
// salida: x0 = pendiente x100
calc_local_slope:
    mov  x1, #0
    mov  x2, #0
    mov  x3, #0

slope_loop:
    cmp  x3, #VENTANA_REG
    b.ge slope_done
    ldr  x4, [x0, x3, lsl #3]
    add  x1, x1, x4
    mul  x5, x3, x4
    add  x2, x2, x5
    add  x3, x3, #1
    b    slope_loop

slope_done:
    mov  x6, #5
    mul  x7, x6, x2
    mov  x6, #10
    mul  x8, x6, x1
    sub  x7, x7, x8
    mov  x6, #100
    mul  x7, x7, x6
    mov  x6, #50
    sdiv x0, x7, x6
    ret

// Manejo de errores
error_argc:
    mov  x0, #1
    ldr  x1, =msg_err_argc
    mov  x2, len_err_argc
    mov  x8, #64
    svc  #0
    mov  x0, #1
    bl   utils_exit

error_range:
    mov  x0, #1
    ldr  x1, =msg_err_rng
    mov  x2, len_err_rng
    mov  x8, #64
    svc  #0
    mov  x0, #1
    bl   utils_exit

error_column:
    mov  x0, #1
    ldr  x1, =msg_err_col
    mov  x2, len_err_col
    mov  x8, #64
    svc  #0
    mov  x0, #1
    bl   utils_exit

error_open:
    mov  x0, #1
    ldr  x1, =msg_err_opn
    mov  x2, len_err_opn
    mov  x8, #64
    svc  #0
    mov  x0, #1
    bl   utils_exit

error_few_data:
    mov  x0, #1
    ldr  x1, =msg_err_few
    mov  x2, len_err_few
    mov  x8, #64
    svc  #0
    mov  x0, #1
    bl   utils_exit

// copy_str, copia ASCIIZ de x0 a x1
// Salida: x0 = siguiente byte libre en destino
copy_str:
    ldrb w2, [x0]
    cbz  w2, cs_done
    strb w2, [x1]
    add  x0, x0, #1
    add  x1, x1, #1
    b    copy_str
cs_done:
    mov  x0, x1
    ret
