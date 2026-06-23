.global _start

.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

.equ N_VALUES, 30
.equ WEIGHT_SUM, 465

.data
out_path:   .asciz "results/resultado_media.txt"
mod_name:   .asciz "MODULE=WEIGHTED_MEAN\n"
total_v:    .asciz "TOTAL_VALUES=30\n"
lbl_sumx:   .asciz "SUM_X="
lbl_wsum:   .asciz "WEIGHT_SUM=465\n"
lbl_mean:   .asciz "WEIGHTED_MEAN="
nl:         .asciz "\n"

.bss
values_buf: 
    .skip 8 * N_VALUES

out_buf:
    .skip 256

.text
_start:
    bl utils_open_csv
    mov x19, x0 // Guardar el file descriptor del archivo CSV en x19

    mov x1, #1 // Columna 1 (índice 0)
    mov x0, x19 // File descriptor del archivo CSV
    ldr x2, =values_buf
    bl utils_read_int_column // Leer la columna de enteros y almacenarla en values_buf

    mov x0, x19
    bl utils_close_csv // Cerrar el archivo CSV

    ldr x0, =values_buf
    bl sum_values // Calcular la suma de los valores
    mov x21, x0 // Guardar la suma en x21

    ldr x0, =values_buf
    bl weighted_mean // Calcular la media ponderada
    mov x22, x0 // Guardar la media ponderada en x22

    ldr x9, =out_buf // Puntero al buffer de salida
    ldr x0, =mod_name // Copiar el nombre del módulo al buffer de salida

copy_mod:
    // Este bloque me ayudara a copiar el nombre del módulo al buffer de salida
    ldrb w2, [x0] // cargar el byte menos significativo del nombre del módulo
    cbz w2, copy_mod_end // si es 0, terminar de copiar

    strb w2, [x9] // almacenar el byte en el buffer de salida
    add x0, x0, #1 // avanzar al siguiente byte del nombre del módulo
    add x9, x9, #1 // avanzar al siguiente byte del buffer de salida
    b copy_mod // repetir el proceso hasta que se termine de copiar el nombre del módulo

copy_mod_end:
    ldr x0, =total_v // Copiar el total de valores al buffer de

copy_total:
    ldrb w2, [x0] // cargar el byte menos significativo del total de valores
    cbz w2, copy_total_end // si es 0, terminar de copiar

    strb w2, [x9] // almacenar el byte en el buffer de salida
    add x0, x0, #1 // avanzar al siguiente byte del total de valores
    add x9, x9, #1 // avanzar al siguiente byte del buffer de salida
    b copy_total // repetir el proceso hasta que se termine de copiar el total de valores

copy_total_end:
    ldr x0, =lbl_sumx // Copiar la etiqueta de la suma al buffer de salida

copy_sumx:
    // Este bloque me ayudara a copiar la etiqueta de la suma al buffer de salida
    ldrb w2, [x0]
    cbz w2, copy_sumx_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_sumx

copy_sumx_end:
    mov x0, x21 // Mover la suma de valores a x0
    mov x1, x9 // Mover el puntero del buffer de salida a x1
    bl utils_i64_to_str // Convertir la suma de valores a cadena y almacenarla en el buffer de salida
    mov x9, x0 // Actualizar el puntero del buffer de salida

    ldr x0, =nl

copy_nl1:
    ldrb w2, [x0]
    cbz w2, copy_nl1_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_nl1

copy_nl1_end:
    ldr x0, =lbl_wsum

copy_wsum:
    // Copiar la etiqueta de la suma ponderada al buffer de salida
        ldrb w2, [x0]
    cbz w2, copy_wsum_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_wsum

copy_wsum_end:
    ldr x0, =lbl_mean

copy_mean:
    ldrb w2, [x0]
    cbz w2, copy_mean_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_mean

copy_mean_end:
    mov x0, x22
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0

    ldr x0, =nl

copy_nl2:
    ldrb w2, [x0]
    cbz w2, copy_nl2_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_nl2

copy_nl2_end:

    ldr x10, =out_buf
    sub x23, x9, x10

    ldr x0, =out_path
    ldr x1, =out_buf
    mov x2, x23
    bl utils_write_result

    mov x0, #0
    bl utils_exit

// HACIENDO LOS CÁLCULOS DE LA SUMA Y LA MEDIA PONDERADA
// [ SUMA DE LOS VALORES ]
sum_values:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x1, x0 // x0 contiene la dirección del buffer de valores
    mov x2, #0 // Inicializar la suma en 0
    mov x3, #0 // Inicializar el índice en 0
    mov x6, #N_VALUES // Cargar el número total de valores en x6 --por ahora es 30

sum_loop:
    cbz x6, sum_done 
    ldr x4, [x1, x2, lsl #3] // Cargar el valor actual (8 bytes por valor)
    add x3, x3, x4 // Sumar el valor actual a la suma
    add x2, x2, #1 // Incrementar el índice
    sub x6, x6, #1 // Decrementar el contador de valores restantes
    b sum_loop

sum_done:
    mov x0, x3 // Mover la suma final a x0 para devolverla
    // ldp sirve para restaurar los registros x29 y x30 desde la pila y ajustar el puntero de la pila
    ldp x29, x30, [sp], #16
    ret

// [ MEDIA PONDERADA ]
weighted_mean:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x1, x0 // x0 contiene la dirección del buffer de valores
    mov x2, #0 // Inicializar la suma ponderada en 0
    mov x3, #0 // Inicializar el índice en 0
    mov x6, #N_VALUES // Cargar el número total de valores en x6

wm_loop:
    cbz x6, wm_done
    ldr x4, [x1, x2, lsl #3] // Cargar el valor actual (8 bytes por valor)
    add x5, x2, #1 // Calcular el peso correspondiente (índice + 1)
    mul x4, x4, x5 // Multiplicar el valor por su peso
    add x3, x3, x4 // Sumar el valor ponderado a la suma total
    add x2, x2, #1
    sub x6, x6, #1 // Decrementar el contador de valores restantes
    b wm_loop

wm_done:
    mov x4, #WEIGHT_SUM
    sdiv x0, x3, x4
    ldp x29, x30, [sp], #16
    ret