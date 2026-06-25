.equ STDIN, 0 // File descriptor - indica que se va a leer desde la terminal
.equ STDOUT, 1 // File descriptor - indica que se va a escribir en la terminal
.equ BUF_SIZE, 256 // Tamaño del buffer para leer una línea

.data
    csv_path:    .asciz "lecturas.csv" // Ruta del archivo CSV
    msg_nl:      .asciz "\n" // Nueva línea

.bss
    line_buf:    .skip BUF_SIZE // Buffer para almacenar una línea leída

.text
.global utils_open_csv
utils_open_csv:
    mov x0, #-100
    ldr x1, =csv_path
    mov x2, #0 // Flags: O_RDONLY
    mov x3, #0
    mov x8, #56 // syscall: openat
    svc #0

    // x0 = file descriptor del archivo abierto (un +N)
    cmp x0, #0
    blt open_fail // Si x0 < 0, hubo un error al abrir el
    ret

open_fail:
    mov x0, #1 // Código de error
    mov x8, #93 // syscall: exit
    svc #0

.global utils_read_line
utils_read_line:
    mov x5, x0 // Guardar el file descriptor en x5
    mov x6, x1 // Guardar el buffer en x6
    mov x3, #0 // Inicializar el contador de bytes leídos en x3
    sub x4, x2, #1 // Calcular el límite de bytes a leer

read_loop:
    cmp x3, x4 // Comparar el contador con el límite
    blt read_more // Si x3 < x4, continuar leyendo
    b read_done // Si no, terminar la lectura

read_more:
    mov x0, x5
    add x1, x6, x3 // Calcular la dirección del siguiente byte en el buffer
    mov x2, #1 // Leer un byte a la vez
    mov x8, #63 // syscall: read
    svc #0

    cmp x0, #0
    ble read_done // Si x0 <= 0, terminar la lectura

    ldrb w7, [x6, x3] // Cargar el byte leído en w7
    add x3, x3, #1

    cmp w7, #'\n' // Comparar con el carácter de nueva línea
    beq read_done // Si es nueva línea, terminar la lectura

    b read_loop // Continuar leyendo

read_done:
    // wzr indica que es un terminador nulo
    strb wzr, [x6, x3] // Agregar un terminador nulo al final del buffer
    mov x0, x3 // Devolver el número de bytes leídos
    ret

.global utils_parse_i64
utils_parse_i64:
    mov x1, #0
    mov x2, #10 // Base decimal

up_loop:
    ldrb w3, [x0] // Cargar el siguiente byte del string
    
    cmp w3, #'0'
    blt up_done

    cmp w3, #'9'
    bgt up_done

    mul x1, x1, x2
    sub w3, w3, #'0' // Convertir el carácter a su valor numérico
    add x1, x1, x3 // Acumular el valor en x1
    add x0, x0, #1 // Avanzar al siguiente carácter
    b up_loop

up_done:
    mov x0, x1
    ret

read_column:
    mov x2, x0 // Guardar el puntero al buffer en x2
    mov x3, #0 // Inicializar el contador de columnas en x3
    mov x4, x1 // Guardar el índice de la columna a leer en x4

skip_column:
    cmp x3, x4
    blt skip_more
    b read_value

skip_more:
    ldrb w5, [x2] // Cargar el siguiente byte del buffer
    cbz w5, zero_value

    cmp w5, #'\n'
    beq zero_value
    cmp w5, #','
    bne skip_next

    add x2, x2, #1
    add x3, x3, #1
    b skip_column

skip_next:
    add x2, x2, #1
    b skip_column

read_value:
    mov x0, x2
    b utils_parse_i64

zero_value:
    mov x0, #0
    ret

.global utils_read_int_column
utils_read_int_column:
    // x19 = fd, x20 = columna, x21 = buffer, x22 = linea_inicial, x23 = linea_final
    // x24 = linea_actual, x25 = contador de valores leidos
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!

    mov x19, x0 // file descriptor
    mov x20, x1 // indice de columna
    mov x21, x2 // puntero al buffer
    mov x22, x3 // linea inicial (1 = primer dato)
    mov x23, x4 // linea final (inclusive)
    mov x24, #1 // contador de linea actual (empieza en 1 tras el header)
    mov x25, #0 // valores leidos hasta ahora

    // Saltar el encabezado (primera linea del CSV)
    mov x0, x19
    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line

rc_read_next:
    mov x0, x19
    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line
    cmp x0, #0
    ble rc_done          // fin de archivo

    cmp x24, x22
    blt rc_skip          // aun no llegamos a la linea inicial

    cmp x24, x23
    bgt rc_done          // ya pasamos la linea final

    // Leer el valor de la columna solicitada
    ldr x0, =line_buf
    mov x1, x20
    bl read_column

    // segun los videos: lsl indica que se hara un offset de 3 bits a la izquierda
    str x0, [x21, x25, lsl #3] // lsl #3 porque cada valor es de 8 bytes (64 bits)
    add x25, x25, #1

rc_skip:
    add x24, x24, #1
    b rc_read_next

rc_done:
    mov x0, x25 // devolver la cantidad de valores leidos

    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.global utils_count_lines
utils_count_lines:
    // x0 = fd (archivo ya abierto)
    // Devuelve: x0 = cantidad de lineas de datos (sin contar header)
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!

    mov x19, x0       // fd
    mov x20, #0       // contador de lineas

    // Saltar header
    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line

ucl_loop:
    mov x0, x19
    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line
    cmp x0, #0
    ble ucl_done

    add x20, x20, #1
    b ucl_loop

ucl_done:
    mov x0, x20

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.global utils_close_csv
utils_close_csv:
    mov x8, #57
    svc #0
    ret

.global utils_write_result
utils_write_result:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0
    mov x20, x1
    mov x21, x2

    mov x0, #-100
    mov x1, x19
    mov x2, #(1 | 64 | 512) // Flags: O_WRONLY | O_CREAT | O_TRUNC
    mov x3, #0644
    mov x8, #56
    svc #0
    cmp x0, #0
    blt write_fail

    mov x19, x0

    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x8, #64
    svc #0

    mov x0, x19
    mov x8, #57
    svc #0

    // Bloque de restauración de registros y retorno
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

write_fail:
    mov x0, #1
    mov x8, #93
    svc #0

.global utils_i64_to_str
utils_i64_to_str:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!

    mov x19, x0
    mov x20, x1

    cbnz x19, uis_nonzero
    mov w2, #'0'
    strb w2, [x20]
    add x0, x20, #1
    b uis_done

uis_nonzero:
    sub sp, sp, #32 // Reservar espacio en la pila para almacenar los dígitos del número
    mov x2, sp // x2 apunta al espacio reservado en la pila para almacenar los dígitos
    mov x3, #0 
    mov x4, #10

uis_digit:
    udiv x5, x19, x4 // Dividir el número entre 10 para obtener el siguiente dígito
    msub x6, x5, x4, x19 // Calcular el dígito actual (x6 = x19 - x5 * 10)
    add w6, w6, #'0' // Convertir el dígito a su representación ASCII
    strb w6, [x2, x3] // Almacenar el dígito en la pila
    add x3, x3, #1
    mov x19, x5
    cbnz x19, uis_digit // Continuar dividiendo hasta que el número sea 0

    mov x7, #0 // Inicializar el índice para copiar los dígitos en orden inverso

uis_copy:
    // Copiar los dígitos desde la pila al buffer de salida en orden inverso
    sub x3, x3, #1
    ldrb w6, [x2, x3]
    strb w6, [x20, x7]
    add x7, x7, #1
    cbnz x3, uis_copy

    add sp, sp, #32
    add x0, x20, x7

uis_done:
    // Bloque de restauración de registros y retorno
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.global utils_print_string
utils_print_string:
    mov x2, x1
    mov x1, x0
    mov x0, #STDOUT
    mov x8, #64
    svc #0
    ret

.global utils_print_newline
utils_print_newline:
    mov x0, #STDOUT
    ldr x1, =msg_nl
    mov x2, #1
    mov x8, #64
    svc #0
    ret

.global utils_print_i64
utils_print_i64:
    stp x29, x30, [sp, #-16]!
    sub sp, sp, #32
    mov x2, sp

    mov x1, x2
    bl utils_i64_to_str
    mov x1, x2
    sub x2, x0, x1
    mov x0, #STDOUT
    mov x8, #64
    svc #0

    add sp, sp, #32
    ldp x29, x30, [sp], #16
    ret

.global utils_exit
utils_exit:
    mov x8, #93
    svc #0
