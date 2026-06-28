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
// para la clasificacion
trend_asc:  .ascii "ASCENDING\n";  len_trend_asc = . - trend_asc
trend_desc: .ascii "DESCENDING\n"; len_trend_desc = . - trend_desc
trend_stbl: .ascii "STABLE\n";     len_trend_stbl = . - trend_stbl
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
    bge reg_args_ok
    b error_argc // no vienen pues error de argumentos
reg_args_ok:

    // x19=path x20=inicio x21=fin x22=columna
    ldr x19, [sp, #16]   // cargamos el paht del archivo

    ldr x0, [sp, #24]   //cargamos el argumento 2 linea de inicio en x0 
    bl utils_parse_i64  // llamamos a la funcion
    mov x20, x0     //  copiamos el numero de inicio de la fila en x20
    cmp x20, #1     // comparamos si el inicio es menor a 1
    bge reg_start_ok
    b error_start
reg_start_ok:

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
    bge reg_open_ok
    b error_open  // si falla al abrir error

reg_open_ok:
    mov x24, x0     // copiamos el descriptor del archivo en x24
    bl utils_count_lines    // llamamos la funcion 
    mov x26, x0     // copiamod la cantidad de lineas contadas en x26

    // cerrar el descriptor
    mov x0, x24
    mov x8, #57
    svc #0

    // validar que el final no exceda la cantidad de lineas
    cmp x21, x26    // compara el limite con las lineas del archivo
    ble reg_eof_ok
    b error_eof   // salta al error si es mayor
reg_eof_ok:

    // arbimos de nuevo para leer los datos
    mov x0, #-100  // AT_FDCWD
    mov x1, x19    // path lo seguimos teniendo guardado
    mov x2, #0     // O_RDONLY
    mov x8, #56    // syscall openat
    svc #0
    cmp x0, #0
    bge reg_open2_ok
    b error_open

reg_open2_ok:
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
    bge reg_min_ok
    b error_data
reg_min_ok:

    // calcular el numerador, denominador y la pendiente m_x100
    ldr x0, =values_buf // cargamos la direcion del buf
    mov x1, x25 // pasamso a x1 los N valores

    // x0 = M_X100 la pendiente ya escalada por 100 y dividida)
    // x1 = 0 si el denominador fue valido y 1 si fue cero es decir que no se calculo
    bl regresion_calc
    cbnz x1, error_data // camparamos si el denominador es distinto de 0 si es 0 salta al error
    mov x27, x0 // copiamos a x27 la pendiente 

## clasificacion
    // vamos a clasificar la pendiente por medio del signo
    cmp x27, #0
    ble not_asc
    b trend_is_asc
not_asc:
    cmp x27, #0
    bge is_stable
    b trend_is_desc
is_stable:
    // x27 == 0 -> stable, fall through

    ldr x28, =trend_stbl // si no es mayor ni menor a 0 es pendiente 0
    mov x14, len_trend_stbl // copiamops la longitud exacta 
    b trend_done    // salata para hacer la clasificacion
##Fin de clasificacion    

// asecendente
trend_is_asc:
    ldr x28, =trend_asc // carga la direccion del trend_asc en x28 "TREND=ASCENDING"
    mov x14, len_trend_asc   // copiamos la longitud en byte de "ASCENDING"
    b trend_done    // saltamos a

// descendente
trend_is_desc:      
    ldr x28, =trend_desc // cargamos la direccion en x28 de "TREND=DECENDING"
    mov x14, len_trend_desc  // copiamos la longitud en bytes de "DECENDING"

// x28 = puntero al string  x14 = su longitud
trend_done:
// imprimir salidas

    // para CALC=LINEAR_REGRESSION
    mov x0, #1 //STDOUT para salida
    ldr x1, =lbl_calc   // cargamos al texto
    mov x2, len_calc    // copiamos el tamaño del texto o longitud
    mov x8, #64         // escribimos
    svc #0

    // para COLUMN=con numero
    mov x0, #1 //STDOUT
    ldr x1, =lbl_col    // cargamos el texto
    mov x2, len_col     // copiamos el tamaño o longitud
    mov x8, #64
    svc #0
    mov x0, x22 // cargamos el numero almacenado 
    bl print_uint   // convetimos el numero a texto 

    //para WINDOW_START=numero
    mov x0, #1  // STDOUT
    ldr x1, =lbl_ws // cargamos el texto
    mov x2, len_ws  // copiamos el tamaño o longitud
    mov x8, #64
    svc #0
    mov x0, x20 // copiamos la linea inicial almacenada
    bl print_uint

    //para WINDOW_END=numero
    mov x0, #1
    ldr x1, =lbl_we
    mov x2, len_we
    mov x8, #64
    svc #0
    mov x0, x21 // copiamos la linea final almacenada
    bl print_uint

    // para COUNT=numero
    mov x0, #1
    ldr x1, =lbl_cnt
    mov x2, len_cnt
    mov x8, #64
    svc #0
    mov x0, x25 // copiamos los N valores
    bl print_uint

    // para el SLOPE_X100=numero con signo
    mov x0, #1
    ldr x1, =lbl_slope
    mov x2, len_slope
    mov x8, #64
    svc #0
    mov x0, x27 // copiamos la pendiente almacenada
    bl print_uint

    // para el TREND=ASCENDING|DESCENDING|STABLE
    mov x0, #1
    ldr x1, =lbl_trend
    mov x2, len_trend
    mov x8, #64     // escribimos
    svc #0
    mov x0, #1  // volvemos a STDOUT
    mov x1, x28 // copiamos la clasificacion almacenada
    mov x2, x14 // copiamos la longitud del texto
    mov x8, #64     // escribimos
    svc #0

    // para STATUS=OK
    mov x0, #1 // STDOUT
    ldr x1, =lbl_ok
    mov x2, len_ok
    mov x8, #64
    svc #0

    //salida
    mov x0, #0
    mov x8, #93
    svc #0

## Calculo de la regresion
/*
lo que vamos a hacer es a recibir el buffer, N valores
x0= values_buf que sera Y x1=N valores
para esperar 
x0=M_X100 la pendiente * 100 con una division entera
x1= 0 si es exitoso o 1 si fallo o el denominador quedo en 0
*/ 
regresion_calc:
    stp x29, x30, [sp, #-16]!  
    mov x29, sp // ajustamos la pila para darle el espacio a la funcion
    
    mov x9, x0  // copiamos el valor del buf
    mov x10, x1 // copiamos los N valores 

    mov x2, #0  // creamos el contador para la suma en x x2 = suma_x
    mov x3, #0  // creamos el contador para la suma en y x3 = suma_y
    mov x4, #0  // creamos el contador para la suma de x*y  x4 = suma_xy
    mov x5, #0  // creamos el contador para la suma de x*x x5 = suma_x2
    mov x6, #0  // este sera como el indicador de x

reg_loop:
    cmp x6, x10 // comparamos como va el indicador con la cantidad de valores
    bge reg_loop_done // si es mayor o igual salta 

    ldr x7, [x9, x6, lsl#3] // cargamos a x7 la direciion saltando de 8 bytes extrae la lectura de y
    add x2, x2, x6 // hacemos el incremento en x2 del indicador en ese momento de x
    add x3, x3, x7  // incrementamos en y suma_y += y

    mul x8, x6, x7  // x8 sera la mutiplicacion de x * y 
    add x4, x4, x8  // va incremementado para la sumatoria de suma_xy

    mul x8, x6, x6   // x8 = x * x
    add x5, x5, x8   // suma_x2 += x * x

    add x6, x6, #1   // siguiente indice
    b reg_loop

reg_loop_done:
    //  para el numerador = (N * suma_xy) - (suma_x * suma_y)
    mul x11, x10, x4 // x11 = N * suma_xy
    mul x12, x2, x3  // x12 = suma_x * suma_y
    sub x11, x11, x12  // x11 = numerador

    // para el denominador = (N * suma_x2) - (suma_x * suma_x)
    mul x13, x10, x5 // x13 = N * suma_x2
    mul x14, x2, x2  // x14 = suma_x * suma_x
    sub x13, x13, x14 // x13 = denominador

    cbz x13, reg_denom_zero //si el denominador es 0 no se divide

    // m_x100 = (numerador * 100) / denominador con division entera
    mov x15, #100
    mul x11, x11, x15         // x11 = numerador * 100
    sdiv x0, x11, x13         // x0 = m_x100
    mov x1, #0                // x1 = 0  calculo valido
    b reg_calc_done

reg_denom_zero:
    mov x0, #0
    mov x1, #1 // x1 = 1  denominador era cero

reg_calc_done:
    ldp x29, x30, [sp], #16
    ret

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
    