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
lbl_calc: .ascii "CALC=LINEAR_REGRESSION\n"; len_calc = . - lbl_calc // calcula su longitud exacta en bytes
lbl_col: .ascii "COLUMN="; len_col = . - lbl_col    
lbl_ws: .ascii "WINDOW_START="; len_ws = . - lbl_ws
lbl_we: .ascii "WINDOW_END="; len_we = . - lbl_we
lbl_cnt: .ascii "COUNT="; len_cnt = . - lbl_cnt
lbl_slope: .ascii "SLOPE_X100="; len_slope = . - lbl_slope
lbl_trend: .ascii "TREND="; len_trend = . - lbl_trend
lbl_ok: .ascii "STATUS=OK\n"; len_ok = . - lbl_ok
newline: .ascii "\n"
minus_sign: .ascii "-"

// mensajes de errores
msg_err_argc: .ascii "STATUS=ERROR\nERROR=INVALID_ARGS\nDETAIL=EXPECTED_4_ARGS\n"
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
msg_err_data: .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=REGRESSION_REQUIRES_AT_LEAST_2_VALUES\n"
len_err_data = . - msg_err_data

.bss
values_buf: .skip 8 * MAX_VALUES // se reservan 800 bytes
num_buffer: .skip 32    // se reservan 32 bytes para las conversiones

.text
_start:
    // vamos a validar los argumentos  programa,path, inicio, fin y columna
    ldr x0, [sp] // cargamos el valor en la cima de la pila
    cmp x0, #5  // comparamos si vienen los 5 argumentos
    blt error_argc // no vienen pues error de argumentos

    // x19=path x20=inicio x21=fin x22=columna
    ldr x19, [sp, #16]   // cargamos el paht del archivo

    ldr x0, [sp, #24]   //cargamos el argumento 2 linea de inicio en x0 
    bl utils_parse_i64  // llamamos a la funcion
    mov x20, x0     //  copiamos el numero de inicio de la fila en x20
    cmp x20, #1     // comparamos si el inicio es menor a 1
    blt error_start 

    ldr x0, [sp, #32]   // cargamos la linea final en x0
    bl utils_parse_i64 // llamamos a la funcion 
    mov x21, x0 // copiamos el valor de la fila final en x21

    ldr x0, [sp, #40]   // cargamos lo que es la columna seleccionada
    bl utils_parse_i64
    mov x22, x0 // compiamos el numero de la columna en x22

    // validamos el rango
    mov x0, x20 // copiamos el incio como primer argumento
    mov x1, x21 // copiamos el fianl como segundo argumento
    bl utils_validate_range // llamamos la funcion y se evalua si inicio <= fin
    cbnz x0, error_range    //si es distinto de 0 salta al error

    // validacion de columnas
    mov x0, x22     // copiamos el numero de la columna en x0 
    bl utils_validate_column    // hacemos el llamado para que verifique y devuelve 0 si la columna es valida
    cbnz x0, error_column   // si no fue valida salta al error

    //abrimos el archivo
    mov x0, #-100   // AT_FDCWD
    mov x1, x19     // copiamos la direccion del descriptor del archivo
    mov x2, #0      // O_RDONLY
    mov x8, #56     // OPENAT   
    svc #0
    cmp x0, #0      // comparamos el resultado x0
    blt error_open  // si falla al abrir error

    mov x24, x0     // copiamos el descriptor del archivo en x24
    bl utils_count_lines    // llamamos la funcion 
    mov x26, x0     // copiamod la cantidad de lineas contadas en x26

    // cerrar el descriptor
    mov x0, x24
    mov x8, #57
    svc #0

    // validar que el final no exceda la cantidad de lineas
    cmp x21, x26    // compara el limite con las lineas del archivo
    bgt error_eof   // salta al error si es mayor 

    // arbimos de nuevo para leer los datos
    mov x0, #-100  // AT_FDCWD
    mov x1, x19    // path lo seguimos teniendo guardado
    mov x2, #0     // O_RDONLY
    mov x8, #56    // syscall openat
    svc #0
    cmp x0, #0
    blt error_open

    mov x23, x0    // x23 = descriptor del archivo en  la segunda leida

    // vamos a leer la columna dentro del rando de inicio y fin
    mov x0, x23 // copiampos el dato del descriptor del archvio
    mov x1, x22 // copiamos la columna guardada en x22 para leer
    ldr x2, =values_buf // cargamos la direccion del buffer de salida
    mov x3, x20 // copiamos la fila de inicio
    mov x4, x21 // copiamos la fila final
    bl utils_read_int_column    // llamamos a la funcion
    mov x25, x0 // x25 tendra la cantidad de los valores

    // cerramos el archivo
    mov x0, x23 // el descriptor del archivo
    mov x8, #57     // syscall close
    svc #0

    // vamos a validar 2 valores para probar
    cmp x25, #2
    blt error_data

    // para probar
    mov x0, #0
    mov x8, #93
    svc #0

## ERRORES
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
    mov x8, #64                  // syscall write
    svc #0
    mov x0, #1
    mov x8, #93                  // syscall exit
    svc #0
    