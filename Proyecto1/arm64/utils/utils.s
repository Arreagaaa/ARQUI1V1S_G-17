// =============================================================================
// utils.s — Biblioteca común para los 5 módulos ARM64 del invernadero
// =============================================================================
// Proyecto: Invernadero Inteligente IoT — ACYE1 — Grupo 17
// Plataforma: Raspberry Pi 3/4 (ARMv8/AArch64) corriendo Linux
//
// Subrutinas exportadas (ver prólogo de cada una para detalle):
//   utils_open_csv()              → fd en x0
//   utils_read_line(fd, buf, sz)  → bytes leídos en x0
//   utils_parse_i64(ptr)          → entero en x0
//   utils_read_int_column(fd,col,buf) → cantidad en x0
//   utils_close_csv(fd)
//   utils_write_result(path,buf,len)
//   utils_i64_to_str(val,buf)     → siguiente posición en x0
//   utils_print_string(ptr,len)
//   utils_print_newline()
//   utils_print_i64(val)
//   utils_exit(code)
//
// Uso desde un módulo:
//     .extern utils_open_csv
//     .extern utils_read_int_column
//     ...
//     bl   utils_open_csv
// =============================================================================

// =============================================================================
// Constantes del sistema (Linux AArch64)
// =============================================================================
.equ SYS_READ,        63
.equ SYS_WRITE,       64
.equ SYS_OPENAT,      56
.equ SYS_CLOSE,       57
.equ SYS_EXIT,        93

.equ AT_FDCWD,        -100
.equ O_RDONLY,        0
.equ O_WRONLY,        1
.equ O_CREAT,         0100
.equ O_TRUNC,         01000
.equ O_WRONLY_CREAT_TRUNC, 0x241

.equ STDIN,           0
.equ STDOUT,          1

.equ BUF_SIZE,        256
.equ N_VALUES,        30

// =============================================================================
// Strings (solo lectura)
// =============================================================================
.section .rodata
.align 3

csv_path:    .asciz "lecturas.csv"
msg_nl:      .asciz "\n"

// =============================================================================
// Buffers compartidos (BSS)
// =============================================================================
.section .bss
.align 3

line_buf:    .skip BUF_SIZE

// =============================================================================
// Código
// =============================================================================
.section .text

// =============================================================================
// utils_open_csv — abre lecturas.csv en modo solo lectura
// -----------------------------------------------------------------------------
// Entrada:  (ninguna)
// Salida:   x0 = file descriptor (entero ≥ 0)
// Efecto:   si el archivo no existe, sale con código 1
// =============================================================================
.global utils_open_csv
utils_open_csv:
    mov  x0, #AT_FDCWD
    adr  x1, csv_path
    mov  x2, #O_RDONLY
    mov  x3, #0
    mov  x8, #SYS_OPENAT
    svc  #0
    cmp  x0, #0
    b.lt open_fail
    ret
open_fail:
    mov  x0, #1
    mov  x8, #SYS_EXIT
    svc  #0

// =============================================================================
// utils_read_line — lee una línea (hasta '\n') desde un descriptor
// -----------------------------------------------------------------------------
// Entrada:
//   x0 = fd
//   x1 = buffer destino
//   x2 = tamaño máximo del buffer
// Salida:
//   x0 = cantidad de bytes leídos (incluyendo '\n'; 0 = EOF/error)
//   buffer con los bytes leídos + NUL al final
// =============================================================================
.global utils_read_line
utils_read_line:
    mov  x5, x0               // x5 = fd
    mov  x6, x1               // x6 = buffer base
    mov  x3, #0               // x3 = count = 0
    sub  x4, x2, #1           // x4 = max_read = size - 1 (espacio para NUL)
url_loop:
    cmp  x3, x4
    b.ge url_done
    mov  x0, x5               // fd
    add  x1, x6, x3           // buf + count
    mov  x2, #1               // 1 byte
    mov  x8, #SYS_READ
    svc  #0
    cmp  x0, #0
    b.le url_done             // EOF o error
    ldrb w7, [x6, x3]         // byte leído
    add  x3, x3, #1
    cmp  w7, #'\n'
    b.eq url_done             // fin de línea
    b    url_loop
url_done:
    strb wzr, [x6, x3]        // null-terminate
    mov  x0, x3               // retornar count
    ret

// =============================================================================
// utils_parse_i64 — convierte string ASCII a entero de 64 bits con signo
// -----------------------------------------------------------------------------
// Entrada:
//   x0 = puntero al inicio de los dígitos ASCII
// Salida:
//   x0 = valor entero
// =============================================================================
.global utils_parse_i64
utils_parse_i64:
    mov  x1, #0               // acc = 0
    mov  x2, #10              // base 10
up_loop:
    ldrb w3, [x0]
    cmp  w3, #'0'
    b.lt up_done
    cmp  w3, #'9'
    b.gt up_done
    mul  x1, x1, x2           // acc *= 10
    sub  w3, w3, #'0'         // char → dígito
    add  x1, x1, x3           // acc += dígito
    add  x0, x0, #1           // avanzar ptr
    b    up_loop
up_done:
    mov  x0, x1               // retornar acc
    ret

// =============================================================================
// parse_column — helper interno: extrae valor entero de columna N en línea CSV
// -----------------------------------------------------------------------------
// Entrada:
//   x0 = puntero a línea CSV (NUL-terminated)
//   x1 = índice de columna (0-based: 0=ID, 1=TEMP, 2=HUM_AIRE, ...)
// Salida:
//   x0 = valor entero de la columna
//
// No es .global: solo se usa internamente desde utils_read_int_column.
// =============================================================================
parse_column:
    mov  x2, x0               // cursor
    mov  x3, #0               // columna actual
    mov  x4, x1               // columna objetivo
pc_skip:
    cmp  x3, x4
    b.ge pc_read
    ldrb w5, [x2]
    cbz  w5, pc_zero
    cmp  w5, #'\n'
    b.eq pc_zero
    cmp  w5, #','
    b.ne pc_skip_next
    add  x2, x2, #1
    add  x3, x3, #1
    b    pc_skip
pc_skip_next:
    add  x2, x2, #1
    b    pc_skip
pc_read:
    mov  x0, x2               // puntero al inicio del valor
    b    utils_parse_i64      // tail-call: parsea y retorna
pc_zero:
    mov  x0, #0
    ret

// =============================================================================
// utils_read_int_column — lee N_VALUES líneas y extrae una columna como enteros
// -----------------------------------------------------------------------------
// Entrada:
//   x0 = fd (archivo CSV ya abierto, posición después del header)
//   x1 = columna a extraer (0-based)
//   x2 = buffer de salida (capacidad para N_VALUES enteros de 8 bytes c/u)
// Salida:
//   x0 = cantidad de valores leídos (N_VALUES si OK, menos si EOF)
// =============================================================================
.global utils_read_int_column
utils_read_int_column:
    stp  x29, x30, [sp, #-16]!
    stp  x19, x20, [sp, #-16]!
    stp  x21, x22, [sp, #-16]!

    mov  x19, x0              // fd
    mov  x20, x1              // col
    mov  x21, x2              // buf
    mov  x22, #0              // count = 0

    // Saltar línea de cabecera
    mov  x0, x19
    adr  x1, line_buf
    mov  x2, #BUF_SIZE
    bl   utils_read_line

ur_loop:
    cmp  x22, #N_VALUES
    b.ge ur_done

    mov  x0, x19
    adr  x1, line_buf
    mov  x2, #BUF_SIZE
    bl   utils_read_line
    cmp  x0, #0
    b.le ur_done

    adr  x0, line_buf
    mov  x1, x20
    bl   parse_column

    str  x0, [x21, x22, lsl #3]
    add  x22, x22, #1
    b    ur_loop

ur_done:
    mov  x0, x22

    ldp  x21, x22, [sp], #16
    ldp  x19, x20, [sp], #16
    ldp  x29, x30, [sp], #16
    ret

// =============================================================================
// utils_close_csv — cierra un descriptor de archivo
// -----------------------------------------------------------------------------
// Entrada: x0 = fd
// =============================================================================
.global utils_close_csv
utils_close_csv:
    mov  x8, #SYS_CLOSE
    svc  #0
    ret

// =============================================================================
// utils_write_result — crea/escribe un archivo de resultados
// -----------------------------------------------------------------------------
// Entrada:
//   x0 = puntero a la ruta del archivo (ASCIIZ)
//   x1 = buffer con datos a escribir
//   x2 = cantidad de bytes a escribir
// =============================================================================
.global utils_write_result
utils_write_result:
    stp  x29, x30, [sp, #-16]!
    stp  x19, x20, [sp, #-16]!
    stp  x21, x22, [sp, #-16]!

    mov  x19, x0              // path
    mov  x20, x1              // buf
    mov  x21, x2              // len

    mov  x0, #AT_FDCWD
    mov  x1, x19
    mov  x2, #O_WRONLY_CREAT_TRUNC
    mov  x3, #0644
    mov  x8, #SYS_OPENAT
    svc  #0
    cmp  x0, #0
    b.lt write_fail

    mov  x19, x0              // fd

    mov  x0, x19
    mov  x1, x20
    mov  x2, x21
    mov  x8, #SYS_WRITE
    svc  #0

    mov  x0, x19
    mov  x8, #SYS_CLOSE
    svc  #0

    ldp  x21, x22, [sp], #16
    ldp  x19, x20, [sp], #16
    ldp  x29, x30, [sp], #16
    ret

write_fail:
    mov  x0, #1
    mov  x8, #SYS_EXIT
    svc  #0

// =============================================================================
// utils_i64_to_str — convierte entero de 64 bits a string ASCII
// -----------------------------------------------------------------------------
// Entrada:
//   x0 = valor entero (no-negativo)
//   x1 = buffer destino
// Salida:
//   x0 = puntero al siguiente byte libre en el buffer
// =============================================================================
.global utils_i64_to_str
utils_i64_to_str:
    stp  x29, x30, [sp, #-16]!
    stp  x19, x20, [sp, #-16]!

    mov  x19, x0              // valor
    mov  x20, x1              // buffer

    cbnz x19, uis_nonzero
    mov  w2, #'0'
    strb w2, [x20]
    add  x0, x20, #1
    b    uis_done

uis_nonzero:
    sub  sp, sp, #32          // buffer temporal en pila
    mov  x2, sp
    mov  x3, #0               // contador dígitos
    mov  x4, #10              // divisor
uis_digit:
    udiv x5, x19, x4
    msub x6, x5, x4, x19
    add  w6, w6, #'0'
    strb w6, [x2, x3]
    add  x3, x3, #1
    mov  x19, x5
    cbnz x19, uis_digit

    mov  x7, #0               // índice de escritura
uis_copy:
    sub  x3, x3, #1
    ldrb w6, [x2, x3]
    strb w6, [x20, x7]
    add  x7, x7, #1
    cbnz x3, uis_copy

    add  sp, sp, #32
    add  x0, x20, x7

uis_done:
    ldp  x19, x20, [sp], #16
    ldp  x29, x30, [sp], #16
    ret

// =============================================================================
// utils_print_string — imprime un string en stdout
// -----------------------------------------------------------------------------
// Entrada: x0 = puntero, x1 = longitud
// =============================================================================
.global utils_print_string
utils_print_string:
    mov  x2, x1               // len
    mov  x1, x0               // ptr
    mov  x0, #STDOUT
    mov  x8, #SYS_WRITE
    svc  #0
    ret

// =============================================================================
// utils_print_newline — imprime un salto de línea en stdout
// =============================================================================
.global utils_print_newline
utils_print_newline:
    mov  x0, #STDOUT
    adr  x1, msg_nl
    mov  x2, #1
    mov  x8, #SYS_WRITE
    svc  #0
    ret

// =============================================================================
// utils_print_i64 — imprime un entero de 64 bits en stdout
// -----------------------------------------------------------------------------
// Entrada: x0 = valor entero
// =============================================================================
.global utils_print_i64
utils_print_i64:
    stp  x29, x30, [sp, #-16]!
    sub  sp, sp, #32
    mov  x2, sp               // buffer temporal en pila

    mov  x1, x2
    bl   utils_i64_to_str
    // x0 = end, x2 = start
    mov  x1, x2
    sub  x2, x0, x1           // longitud
    mov  x0, #STDOUT
    mov  x8, #SYS_WRITE
    svc  #0

    add  sp, sp, #32
    ldp  x29, x30, [sp], #16
    ret

// =============================================================================
// utils_exit — termina el programa con un código de salida
// -----------------------------------------------------------------------------
// Entrada: x0 = código de salida
// =============================================================================
.global utils_exit
utils_exit:
    mov  x8, #SYS_EXIT
    svc  #0
