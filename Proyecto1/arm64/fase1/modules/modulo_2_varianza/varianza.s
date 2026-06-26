.global _start

// llamado de utils para modulo 2
.extern utils_parse_i64
.extern utils_validate_range    //  para validar el rango
.extern utils_validate_column   // validar la column
.extern utils_read_int_column   // para leer la columna
.extern utils_write_result      // para escribir los resultados
.extern utils_i64_to_str
.extern utils_exit              // salida


// Constantes
.equ MAX_VALUES, 100    // la capacidad maxima de valores obtenidos
// .equ COL_TEMP, 1 // Columna de temperatura esto 

.data
out_path:   .asciz "results/resultado_varianza.txt"
lbl_calc:   .asciz "CALC=VARIANCE\n"
lbl_colum:  .asciz "COLUMN="
lbl_ws:     .asciz "WINDOW_START="
lbl_we:     .asciz "WINDOW_END="
lbl_cnt:    .asciz "COUNT="
lbl_sumx:   .asciz "SUM_X="
lbl_mean:   .asciz "MEAN="
lbl_var:    .asciz "VARIANCE="
lbl_std:    .asciz "STD_DEV="
lbl_ok:     .asciz "STATUS=OK\n"
nl:         .asciz "\n"

msg_err_argc: .ascii "STATUS=ERROR\nERROR=INVALID_ARGS\nDETAIL=EXPECTED_4_ARGS\n"
len_err_argc = . - msg_err_argc
msg_err_rng: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=START_END_INVALID\n"
len_err_rng = . - msg_err_rng
msg_err_col: .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_MUST_BE_1_TO_6\n"
len_err_col = . - msg_err_col
msg_err_opn: .ascii "STATUS=ERROR\nERROR=FILE_NOT_FOUND\nDETAIL=COULD_NOT_OPEN_FILE\n"
len_err_opn = . - msg_err_opn

.bss
values_buf: .skip 8 * MAX_VALUES
out_buf:   .skip 256   // para el txt de salida


.text
_start:
    ldr x0, [sp]    // leemos cuantos argumentos llegaron y vemos que sean 4 mas el nombre del programa
    cmp x0, #5
    blt error_argc

    // leemos cada argumento del stack x19=path, x20=inicio, x21=fin, x22=columna
    ldr x19, [sp, #16] // direccion del string con el path del csv
    ldr x0, [sp, #24]
    bl utils_parse_i64
    mov x20, x0 // fila de inicio, ya convertida a numero

    ldr x0, [sp, #32]
    bl utils_parse_i64
    mov x21, x0 // fila de fin ya convertida a numero

    ldr x0, [sp, #40]
    bl utils_parse_i64
    mov x22, x0 // columna para leer ya convertida a numero

    // validamos que el rango tenga sentido que el inicio <= fin
    mov x0, x20
    mov x1, x21
    bl utils_validate_range
    cbnz x0, error_rango

    // validamos que la columna este en el rango permitido
    mov x0, x22
    bl utils_validate_column    // llamamos a la funcion que lee y almacena en values_buf
    cbnz x0, error_columna      // x0 == 0 si x0 != 0 hubo error de lectura

    // abrimos el archivo usando los parametros que mandamos
    mov x0, #-100    // AT_FDCWD es para abrir relativo al directorio actual
    mov x1, x19      // path del csv que guardamos arriba en x19
    mov x2, #0       // O_RDONLY
    mov x3, #0
    mov x8, #56      // syscall openat
    svc #0
    cmp x0, #0
    blt error_open

    mov x23, x0     // copiamos en x23 el descriptor del archivo para que no se pierda

    // ahora para leer la columna se necesitan 5 datos descriptor, column, desnito, (inicio,fin)
    mov x0, x23              // descriptor del archivo csv, lo regresamos a x0 para pasarlo como parametro
    mov x1, x22              // columna a leer la que vino de argv
    ldr x2, =values_buf      // direccion del buffer donde se guardaron los valores
    mov x3, x20              // fila de inicio
    mov x4, x21              // fila de fin
    bl utils_read_int_column //llamamos a la funcion
    mov x24, x0              // x24 tiene cuantos valores se leyeron realmente

    // ahora cerramos el archivo con syscall close
    mov x0, x23     // descriptor del archivo
    mov x8, #57     // cerramos el archivo
    svc #0

    ldr x0, =values_buf     // cargamos la direcion del buf
    mov x1, x24     // copiamos los valores que hay 
    bl mean_value   // llamamos la funcion para calcular la media de los valores obtenidos
    mov x26, x0     // copiamos el resultado de la media en x26
    mov x27, x1     // copiamos la suma real en x27

    ldr x0, =values_buf     
    mov x1, x24              // copiamos otra vez la cantidad N de valores
    mov x2, x26              // copiamos la media 
    bl variance_value        // llamamos la funcion para calcular la varianza
    mov x28, x0              // copiamos la varianza en x28

    mov x0, x28
    bl isqrt_value           // llamamos a la funcion para calcular la raiz cuadrada entera de la varianza
    mov x10, x0              // copiamos la desviacion estandar en x10

    ldr x9, =out_buf         // cargamos la direccion del buffer de salida
    ldr x0, =lbl_calc        // cargamos la etiqueta del modulo al buffer de salida

//falta actualizar las funciones de inicio sigo al rato

// funciones inicio

copy_mod:   // sirve para copiar el nombre del modulo al buffer de salida
    ldrb w2, [x0]   // cargamos el byte del nombre del modulo
    cbz w2, copy_mod_end    // si es 0 termina de copiar

    strb w2, [x9]   // guarda el byte en el buffer
    add x0, x0, #1  // avanza al siguiente byte del nombre
    add x9, x9, #1  // avanza al siguiente byte del buff de salida
    b copy_mod      // se repite la funcion hasta que copie el nombre

copy_mod_end:
    ldr x0, =total_v // cargamos a x0 el total de los valores del bff de salida


copy_total:
    ldrb w2, [x0] // cargamos el byte menos significativo del total de valores
    cbz w2, copy_total_end // si es 0 termina de copiar

    strb w2, [x9] // almacenar el byte en el buffer de salida
    add x0, x0, #1 // avanzar al siguiente byte del total de valores
    add x9, x9, #1 // avanzar al siguiente byte del buff de salida
    b copy_total // repetir la funcion hasta que se termine de copiar el total de valores

copy_total_end:
    ldr x0, =lbl_mean   // cargamos ña direccion de la media en el bff de salida


copy_mean_lbl:
    ldrb w2, [x0]
    cbz w2, copy_mean_lbl_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_mean_lbl

copy_mean_lbl_end:
    mov x0, x21     // copiamos la media a x0
    mov x1, x9      // copiamos el puntero del buffer de salida a x1
    bl utils_i64_to_str // se convierte la media a cadena y almacenarla en el buffer de salida
    mov x9, x0      // se actualiza el puntero del buffer de salida

    ldr x0, =nl     // newline


// primer salto de linea
copy_nl1:
    ldrb w2, [x0]
    cbz w2, copy_nl1_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_nl1

copy_nl1_end:
    ldr x0, =lbl_var // cargo la etiqueta de la varianza al buffer de salida

copy_var_lbl:
    ldrb w2, [x0]
    cbz w2, copy_var_lbl_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_var_lbl

copy_var_lbl_end:
    mov x0, x22 // Mover la varianza a x0
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0

    ldr x0, =nl


// segundo salto de linea
copy_nl2:
    ldrb w2, [x0]
    cbz w2, copy_nl2_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_nl2

copy_nl2_end:
    ldr x0, =lbl_std // Copiar la etiqueta de la desviacion estandar al buffer de salida

copy_std_lbl:
    ldrb w2, [x0]
    cbz w2, copy_std_lbl_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_std_lbl

copy_std_lbl_end:
    mov x0, x23 // Mover la desviacion estandar a x0
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0

    ldr x0, =nl

// tercer salto de linea
copy_nl3:
    ldrb w2, [x0]
    cbz w2, copy_nl3_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_nl3

copy_nl3_end:
    ldr x10, =out_buf   // cargamos la direcion del buffer de salida en x10
    sub x24, x9, x10 // x24 = cantidad total de bytes escritos en buffer de salida

    ldr x0, =out_path
    ldr x1, =out_buf
    mov x2, x24
    bl utils_write_result

    mov x0, #0
    bl utils_exit

error_lectura:
    mov x0, #1 // STDOUT
    ldr x1, =err_read
    mov x2, #42 // longitud del mensaje de error
    mov x8, #64 // syscall write
    svc #0

    mov x0, #1
    bl utils_exit

// funciones final

// calculos inicio

## MEDIA
mean_value:
    stp x29, x30, [sp, #-16]!
    mov x29, sp 
    mov x1, x0  // x0 contiene la dirección del buffer de valores
    mov x2, #0  // inicializamos la suma en 0
    mov x3, #0  // inicializamos el contador en 0
    mov x6, #N_VALUES   // copiamos el total de valores en x6

mean_loop:
    cbz x6, mean_done
    ldr x4, [x1, x3, lsl #3] // cargamos el valor actual (8 bytes por valor)
    add x2, x2, x4 // Suma el valor actual a la suma
    add x3, x3, #1 // Incrementar el índice
    sub x6, x6, #1 // Decrementar el contador de valores restantes
    b mean_loop

mean_done:
    mov x5, #N_VALUES   // copiamos en x5 los valores
    sdiv x0, x2, x5     // hacemos una division entera -- media = suma / N_VALUES (entera)
    ldp x29, x30, [sp], #16
    ret
## Fin media

## VARIANZA: 
// Entrada en  x0 == puntero al buffer de valores y  x1 == media ya calculada
variance_value:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x2, x0 // x2 = puntero al buffer de valores
    mov x7, x1 // x7 = media
    mov x3, #0 // Inicializar la suma de diferencias al cuadrado en 0
    mov x4, #0 // Inicializar el índice en 0
    mov x6, #N_VALUES // cargamos el número total de valores en x6

var_loop:
    cbz x6, var_done
    ldr x5, [x2, x4, lsl #3] // cargamos el valor actual
    sub x5, x5, x7 // diferencia = valor - media
    mul x5, x5, x5 // diferencia al cuadrado
    add x3, x3, x5 // acumular en la suma
    add x4, x4, #1
    sub x6, x6, #1
    b var_loop

var_done:
    mov x5, #N_VALUES
    sdiv x0, x3, x5 // division entera de varianza = suma de diferencias al cuadrado / N_VALUES
    ldp x29, x30, [sp], #16
    ret
## Fin varianza

## RAIZ CUADRADA ENTERA  (metodo de Newton )
// Entrada x0 = numero
// Salida  x0 = raiz cuadrada entera aproximada

isqrt_value:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    cmp x0, #0
    beq isqrt_ret
    cmp x0, #1
    beq isqrt_ret

    mov x2, x0 // x2 = numero original
    mov x1, x0 // x1 = aproximacion actual

isqrt_iter:
    sdiv x3, x2, x1 // x3 = x2/x1 
    add x3, x3, x1  //x3 += x1
    lsr x3, x3, #1 // desplazamos a la derecha -- siguiente aproximacion = (numero/aprox + aprox) / 2

    cmp x3, x1
    bge isqrt_conv

    mov x1, x3
    b isqrt_iter

isqrt_conv:
    mov x0, x1

isqrt_ret:
    ldp x29, x30, [sp], #16
    ret
## Fin raiz cuadrada

// calculos final