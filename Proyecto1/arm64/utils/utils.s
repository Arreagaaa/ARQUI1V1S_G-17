// =============================================================================
// utils.s — Biblioteca común para los 5 módulos ARM64 del invernadero
// =============================================================================
// Proyecto: Invernadero Inteligente IoT — ACYE1 — Grupo 17
// Plataforma: Raspberry Pi 3/4 (ARMv8/AArch64) corriendo Linux
//
// Esta biblioteca es compartida por los 5 módulos individuales y les provee:
//   - Constantes de syscall (read/write/exit/mmap para abrir lecturas.csv)
//   - Constantes de tamaño de buffers y errores
//   - Subrutina de lectura de una línea desde STDIN o desde un descriptor
//   - Subrutina de conversión ASCII → entero con signo
//   - Subrutina de conversión entero → ASCII
//   - Subrutina de impresión de strings y enteros
//   - Subrutina para parsear una columna entera del CSV
//   - Subrutina para abrir y cerrar el archivo lecturas.csv
//
// TODO: biblioteca común
//   - Implementar las subrutinas declaradas con `.global` abajo
//   - Mantener ABI AArch64: preservar x19-x28 y sp; usar x0-x7 para args/ret
//   - Documentar cada subrutina con prólogo/epílogo y propósito
//   - Reutilizar patrones de 02_ARM64/lessons/{10,11,13} del repo auxiliar
//
// Uso desde un módulo (ej. modulo_1_media.s):
//     .extern utils_open_csv
//     .extern utils_read_int_column
//     .extern utils_print_i64
//     .extern utils_write_result
//     .extern utils_exit
//
// Compilación (vía Makefile del directorio arm64/):
//     as -g utils/utils.s -o build/utils.o
//     as -g modules/modulo_1_media/media.s -o build/media.o
//     ld build/media.o build/utils.o -o build/media
// =============================================================================

.section .data

// Constantes exportadas (visibles para los módulos que enlazan este objeto)
.equ SYS_READ,     63
.equ SYS_WRITE,    64
.equ SYS_OPENAT,   56
.equ SYS_CLOSE,    57
.equ SYS_EXIT,     93
.equ SYS_BRK,     214

.equ O_RDONLY,     0
.equ STDIN,        0
.equ STDOUT,       1
.equ STDERR,       2

.equ BUF_SIZE,    256
.equ PATH_LEN,    128
.equ N_VALUES,     30        // exactamente 30 lecturas reales (enunciado 9.2)

// Mensajes estándar
msg_nl:        .ascii "\n"
msg_nl_len = . - msg_nl

// Buffer compartido (1 sola línea a la vez)
.align 3
.section .bss
.lcomm csv_buffer,     BUF_SIZE
.lcomm line_buffer,    BUF_SIZE
.lcomm path_buffer,    PATH_LEN
.lcomm result_buffer,  BUF_SIZE

// -----------------------------------------------------------------------------
// Subrutinas a implementar (declaradas con .global para que los módulos
// individuales las enlacen con `.extern nombre` y llamen con `bl nombre`).
// -----------------------------------------------------------------------------

.section .text
.global utils_print_string
.global utils_print_newline
.global utils_print_i64
.global utils_read_line
.global utils_parse_i64
.global utils_open_csv
.global utils_close_csv
.global utils_read_int_column
.global utils_write_result
.global utils_exit

// (Los cuerpos de las subrutinas se implementan en grupo antes de que cada
//  integrante compile su módulo individual. Mientras tanto, cada .s puede
//  tener su propia versión mínima sin romper el make all — el Makefile
//  solo compila cada módulo con utils.o si utils.s está presente.)

utils_print_string:
    // x0 = puntero, x1 = longitud
    mov x8, #SYS_WRITE
    mov x2, x1
    mov x0, #STDOUT
    // x1 ya tiene el puntero
    svc #0
    ret

utils_print_newline:
    mov x0, #STDOUT
    adr x1, msg_nl
    mov x2, msg_nl_len
    mov x8, #SYS_WRITE
    svc #0
    ret

utils_print_i64:
    // TODO: implementar conversión entero → ASCII
    ret

utils_read_line:
    // TODO: implementar lectura de una línea
    ret

utils_parse_i64:
    // TODO: implementar conversión ASCII → entero
    ret

utils_open_csv:
    // TODO: abrir lecturas.csv (syscall openat) y devolver fd en x0
    ret

utils_close_csv:
    // TODO: cerrar fd (x0)
    ret

utils_read_int_column:
    // x0 = columna (1-based), x1 = puntero a buffer de salida (30 enteros)
    // Devuelve en x0 cantidad de valores leídos
    // TODO: recorrer N_VALUES líneas y extraer la columna
    ret

utils_write_result:
    // x0 = puntero al buffer con texto a escribir en resultado_*.txt
    // x1 = longitud
    // TODO: abrir (o crear/truncar) el archivo de salida y escribir
    ret

utils_exit:
    // x0 = código de salida
    mov x8, #SYS_EXIT
    svc #0
