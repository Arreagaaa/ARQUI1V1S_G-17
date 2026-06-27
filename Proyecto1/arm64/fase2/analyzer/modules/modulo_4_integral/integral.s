// modulo_4_integral_error.s — Integrante 3 — Grupo 17
.equ MAX_VALUES, 1000

.extern utils_open_csv
.extern utils_read_int_column
.extern utils_parse_i64
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit


.section .rodata
.align 3
out_path:      .asciz "results/resultado_integral.txt"

.section .bss
.align 3
values_buf:  .skip 8 * MAX_VALUES
out_buf:     .skip 512

.section .text
.global _start

_start:

ldr x0, [sp] // argc
cmp x0, #6 // Necesitamos 5 parametros (prog + file + start + end + col + ideal)
blt error_exit



// Extraer argumentos de la pila (Stack)
ldr x19, [sp, #16] // argv[1]: archivo (ignorado si usas utils modificado, o usado aqui)
ldr x20, [sp, #24] // argv[2]: linea_inicial
ldr x21, [sp, #32] // argv[3]: linea_final
ldr x22, [sp, #40] // argv[4]: columna
ldr x27, [sp, #48] // argv[5]: IDEAL

// Convertir textos a numeros
mov x0, x20
bl utils_parse_i64
mov x20, x0 // x20 = start_line

mov x0, x21

bl utils_parse_i64
mov x21, x0 // x21 = end_line
mov x0, x22
bl utils_parse_i64
mov x22, x0 // x22 = column
mov x0, x27
bl utils_parse_i64
mov x27, x0 // x27 = IDEAL


// Abrir y leer CSV



bl utils_open_csv


mov x19, x0 // x19 = fd
mov x0, x19
mov x1, x22
adr x2, values_buf
mov x3, x20
mov x4, x21

bl utils_read_int_column

cmp x0, #0
ble error_exit
mov x25, x0 // x25 = N (COUNT)
mov x0, x19

bl utils_close_csv

// CÁLCULO: INTEGRAL DEL ERROR  TRAPECIOS

mov x28, #0 // x28 = AREA_ERROR (Acumulador total)
mov x10, #0 // x10 = indice i
sub x26, x25, #1 // x26 = N - 1 (Limite del ciclo)


cmp x26, #0
ble fin_integral // Si hay menos de 2 valores, no hay trapecio
adr x12, values_buf
ciclo_integral:


fin_integral:

   

copy_str:
    
    ret
    