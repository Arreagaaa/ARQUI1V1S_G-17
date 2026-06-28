.equ STDIN, 0
.equ STDOUT, 1
.equ BUF_SIZE, 256

.data
    csv_path: .asciz "lecturas.csv"
    msg_nl:   .asciz "\n"
    err_open_csv: .ascii "Error: no se pudo abrir el archivo\n"
    len_err_open_csv = . - err_open_csv

.bss
    line_buf: .skip BUF_SIZE

.text
.global utils_open_csv
utils_open_csv:
    mov x0, #-100 // AT_FDCWD, path relativo al directorio actual
    ldr x1, =csv_path
    mov x2, #0 // O_RDONLY
    mov x3, #0
    mov x8, #56 // openat
    svc #0
    cmp x0, #0
    bge open_ok
    b open_fail
open_ok:
    ret

open_fail:
    mov x0, #1
    ldr x1, =err_open_csv
    mov x2, len_err_open_csv
    mov x8, #64 // write
    svc #0
    mov x0, #1
    mov x8, #93 // exit
    svc #0

// read_line(fd, buf, max)
.global utils_read_line
utils_read_line:
    mov x5, x0 // fd
    mov x6, x1 // buf
    mov x3, #0 // indice actual
    sub x4, x2, #1 // limite (deja espacio para el \0)

read_loop:
    cmp x3, x4
    bge read_done

read_more:
    mov x0, x5
    add x1, x6, x3
    mov x2, #1
    mov x8, #63 // read, un byte a la vez
    svc #0

    cmp x0, #0
    ble read_done // EOF o error

read_char:
    ldrb w7, [x6, x3]
    add x3, x3, #1
    cmp w7, #'\n'
    beq read_done
    b read_loop

read_done:
    strb wzr, [x6, x3] // terminar string con \0
    mov x0, x3
    ret

// parse_i64(str)
.global utils_parse_i64
utils_parse_i64:
    mov x1, #0 // acumulador
    mov x2, #10

up_loop:
    ldrb w3, [x0]
    cmp w3, #'0'
    bge check_upper
    b up_done
check_upper:
    cmp w3, #'9'
    ble process_digit
    b up_done
process_digit:
    mul x1, x1, x2
    sub w3, w3, #'0'
    add x1, x1, x3
    add x0, x0, #1
    b up_loop

up_done:
    mov x0, x1
    ret

// read_column(line, col_idx)
read_column:
    mov x2, x0 // puntero que avanza
    mov x3, #0 // columnas saltadas
    mov x4, x1 // columna destino

skip_column:
    cmp x3, x4
    bge read_value

skip_more:
    ldrb w5, [x2]
    cbz w5, zero_value // fin de string
    cmp w5, #'\n'
    beq zero_value // fin de linea, columna no existe
    cmp w5, #','
    bne skip_next
    add x2, x2, #1 // avanzar puntero
    add x3, x3, #1 // contar coma = siguiente columna
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

// read_int_column(fd, col, buf, start, end)
.global utils_read_int_column
utils_read_int_column:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!

    mov x19, x0 // fd
    mov x20, x1 // columna
    mov x21, x2 // buffer de salida
    mov x22, x3 // fila inicio
    mov x23, x4 // fila fin
    mov x24, #1 // fila actual (empieza en 1, row 0 es header)
    mov x25, #0 // cantidad guardada

    mov x0, x19
    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line // saltar header

rc_read_next:
    mov x0, x19
    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line
    cmp x0, #0
    ble rc_done // EOF

rc_check_range:
    cmp x24, x22
    bge check_rc_end
    b rc_skip // todavia no llegamos al rango
check_rc_end:
    cmp x23, #0          // end == 0 significa "hasta el final"
    beq store_value
    cmp x24, x23
    ble store_value
    b rc_done // ya pasamos el rango
store_value:
    ldr x0, =line_buf
    mov x1, x20
    bl read_column
    str x0, [x21, x25, lsl #3] // guardar como i64
    add x25, x25, #1

rc_skip:
    add x24, x24, #1
    b rc_read_next

rc_done:
    mov x0, x25 // retorno antes de restaurar, si no ldp pisaria x25
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// count_lines(fd)
.global utils_count_lines
utils_count_lines:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!

    mov x19, x0 // fd
    mov x20, #0 // contador

    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line // saltar header

ucl_loop:
    mov x0, x19
    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line
    cmp x0, #0
    ble ucl_done

ucl_count:
    add x20, x20, #1
    b ucl_loop

ucl_done:
    mov x0, x20
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.global utils_close_csv
utils_close_csv:
    mov x8, #57 // close
    svc #0
    ret

// write_result(path, buf, len)
.global utils_write_result
utils_write_result:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0 // path
    mov x20, x1 // buf
    mov x21, x2 // len

    mov x0, #-100 // AT_FDCWD
    mov x1, x19
    mov x2, #(1 | 64 | 512) // O_WRONLY | O_CREAT | O_TRUNC
    mov x3, #0644 // permisos rw-r--r--
    mov x8, #56 // openat
    svc #0
    cmp x0, #0
    bge write_ok
    b write_fail
write_ok:

    mov x19, x0 // fd del archivo creado
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x8, #64 // write
    svc #0

    mov x0, x19
    mov x8, #57 // close
    svc #0

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

write_fail:
    mov x0, #1
    mov x8, #93 // exit
    svc #0

// convierte entero a string
.global utils_i64_to_str
utils_i64_to_str:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!

    mov x19, x0 // numero
    mov x20, x1 // buf destino
    cbnz x19, uis_nonzero
    mov w2, #'0'
    strb w2, [x20]
    add x0, x20, #1
    b uis_done

uis_nonzero:
    sub sp, sp, #32 // buffer temporal para digitos al reves
    mov x2, sp
    mov x3, #0
    mov x4, #10

uis_digit:
    udiv x5, x19, x4
    msub x6, x5, x4, x19 // x6 = x19 % 10
    add w6, w6, #'0'
    strb w6, [x2, x3]
    add x3, x3, #1
    mov x19, x5
    cbnz x19, uis_digit

    mov x7, #0

uis_copy: // invertir los digitos al buf destino
    sub x3, x3, #1
    ldrb w6, [x2, x3]
    strb w6, [x20, x7]
    add x7, x7, #1
    cbnz x3, uis_copy

    add sp, sp, #32
    add x0, x20, x7

uis_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// print_string(buf, len)
.global utils_print_string
utils_print_string:
    mov x2, x1
    mov x1, x0
    mov x0, #STDOUT
    mov x8, #64 // write
    svc #0
    ret

.global utils_print_newline
utils_print_newline:
    mov x0, #STDOUT
    ldr x1, =msg_nl
    mov x2, #1
    mov x8, #64 // write
    svc #0
    ret

// print_i64(num)
.global utils_print_i64
utils_print_i64:
    stp x29, x30, [sp, #-16]!
    sub sp, sp, #32
    mov x2, sp
    mov x1, x2
    bl utils_i64_to_str
    mov x1, x2
    sub x2, x0, x1 // longitud = ptr_fin - ptr_inicio
    mov x0, #STDOUT
    mov x8, #64 // write
    svc #0
    add sp, sp, #32
    ldp x29, x30, [sp], #16
    ret

// valida rango inicio y fin
.global utils_validate_range
utils_validate_range:
    cmp x0, #1
    bge check_end_ge_start
    b range_invalid
check_end_ge_start:
    cmp x1, x0
    bge valid_range
    b range_invalid
valid_range:
    mov x0, #0
    ret

range_invalid:
    mov x0, #-1
    ret

// valida columna 1 a 6
.global utils_validate_column
utils_validate_column:
    cmp x0, #1
    bge check_col_max
    b col_invalid
check_col_max:
    cmp x0, #6
    ble col_valid
    b col_invalid
col_valid:
    mov x0, #0
    ret

col_invalid:
    mov x0, #-1
    ret

.global utils_exit
utils_exit:
    mov x8, #93 // exit
    svc #0
