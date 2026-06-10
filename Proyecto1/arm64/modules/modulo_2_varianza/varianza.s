// ========================================================================
// MÓDULO 2: VARIANZA Y DESVIACIÓN ESTÁNDAR (ARM64)
// Calcula la media, varianza y desviación estándar de 30 lecturas de
// temperatura del archivo lecturas.csv (columna TEMP)
// ========================================================================

.global _start   // Declara _start como símbolo global (punto de entrada)
.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_i64_to_str
.extern utils_write_result
.extern utils_exit

// ========================================================================
// DEFINICIONES DE SYSCALLS (llamadas al sistema en ARM64 Linux)
// ========================================================================
.equ LEER,63      // Syscall para leer de un archivo
.equ ESCRIBIR,64  // Syscall para escribir en un archivo
.equ ABRIR,56     // Syscall para abrir/crear un archivo
.equ CERRAR,57    // Syscall para cerrar un archivo
.equ SALIR,93     // Syscall para terminar el programa

// ========================================================================
// FLAGS PARA EL SYSCALL ABRIR (parámetros de cómo abrir archivos)
// ========================================================================
.equ DIR_ACTUAL,-100      // Bandera para abrir en directorio actual
.equ SOLO_LECTURA,0       // O_RDONLY: abrir solo lectura
.equ SOLO_ESCRITURA,1     // O_WRONLY: abrir solo escritura
.equ CREAR,64             // O_CREAT: crear si no existe
.equ VACIAR,512           // O_TRUNC: borrar contenido si existe
.equ PERMISOS_ARCHIVO,384 // Permisos rw-rw-r-- (0600 octal)

// ========================================================================
// CONSTANTES DEL PROGRAMA
// ========================================================================
.equ N_VALUES,30  // Leeremos exactamente 30 temperaturas

// ========================================================================
// SECCIÓN .rodata: STRINGS CONSTANTES (no cambian en ejecución)
// ========================================================================
.section .rodata

// Nombres de archivos
archivo_entrada:  .asciz "lecturas.csv"
archivo_salida:   .asciz "results/resultado_varianza.txt"

// Etiquetas para el formato de salida
label_module:     .asciz "MODULE=VARIANCE"
label_total:      .asciz "TOTAL_VALUES="
label_med:        .asciz "MEAN="
label_var:        .asciz "VARIANCE="
label_desv:       .asciz "STD_DEV="
newline:          .asciz "\n"

// ========================================================================
// SECCIÓN .bss: VARIABLES EN MEMORIA (reservadas pero sin inicializar)
// ========================================================================
.section .bss
.align 8          // Alinear a 8 bytes (64 bits)

// Variables
buffer_linea:           .space 256        // Buffer para leer líneas del CSV
descriptor_csv:         .space 8          // Almacena el ID del archivo abierto
array_temperaturas:     .space 30 * 8     // Array de 30 temperaturas (8 bytes cada una)
buffer_salida:          .space 512        // Buffer para construir el texto de salida

// ========================================================================
// SECCIÓN .text: CÓDIGO EJECUTABLE
// ========================================================================
.section .text

// ========================================================================
// FUNCIÓN PRINCIPAL: _start
// Flujo principal del programa
// ========================================================================
_start:
    stp x29, x30, [sp, #-16]!  // Guardar x29 y x30 en stack (prologue)
    mov x29, sp                 // x29 ahora apunta al frame actual

    // ====================================================================
    // PASO 1: ABRIR EL ARCHIVO lecturas.csv
    // ====================================================================
    bl utils_open_csv           // Abrir lecturas.csv usando la biblioteca común
    cmp x0, #0                  // Comparar: ¿es error? (ID < 0)
    blt _exit_error             // Si error, salir

    ldr x1, =descriptor_csv     // x1 = dirección donde guardar el ID
    str x0, [x1]                // Guardar ID del archivo en descriptor_csv

    // ====================================================================
    // PASO 2: SALTAR LA CABECERA DEL CSV
    // Leemos la primera línea (ID,TEMP,HUM_AIRE...) y la descartamos
    // ====================================================================
    // utils_read_int_column se encarga de saltar la cabecera.

    // ====================================================================
    // PASO 3: LEER 30 TEMPERATURAS DEL CSV EN UN LOOP
    // ====================================================================
    mov x0, #1                  // x0 = 1 (extraer columna 1 = TEMP)
    ldr x1, =array_temperaturas // x1 = dirección del array
    bl utils_read_int_column    // Leer columna TEMP completa con utils
    cmp x0, #N_VALUES           // ¿se leyeron exactamente 30 valores?
    bne _exit_error             // Si no, salir con error
    // ====================================================================
    // PASO 4: CALCULAR LA MEDIA (promedio)
    // ====================================================================
    ldr x0, =array_temperaturas // x0 = dirección del array
    bl calcular_media           // Llamar función que suma y divide por 30
    mov x19, x0                 // x19 = media (guardar resultado)

    // ====================================================================
    // PASO 5: CALCULAR LA VARIANZA
    // Varianza = Σ(Xi - media)² / N
    // ====================================================================
    ldr x0, =array_temperaturas // x0 = dirección del array
    mov x1, x19                 // x1 = media (necesaria para cálculo)
    bl calcular_varianza        // Calcular varianza
    mov x22, x0                 // x22 = varianza (guardar resultado)

    // ====================================================================
    // PASO 6: CALCULAR DESVIACIÓN ESTÁNDAR (raíz de la varianza)
    // ====================================================================
    mov x0, x22                 // x0 = varianza
    bl isqrt                    // Calcular raíz cuadrada
    mov x23, x0                 // x23 = desviación estándar

    // ====================================================================
    // PASO 7: CONSTRUIR TEXTO DE SALIDA EN BUFFER_SALIDA
    // Construimos: MODULE=VARIANCE\nTOTAL_VALUES=30\nMEAN=X\n...
    // ====================================================================
    ldr x24, =buffer_salida     // x24 = posición actual en buffer

    // Línea 1: MODULE=VARIANCE
    mov x0, x24                 // x0 = posición actual
    ldr x1, =label_module       // x1 = "MODULE=VARIANCE"
    bl copy_str                 // Copiar string al buffer
    mov x24, x0                 // x24 = nueva posición

    mov x0, x24                 // x0 = posición actual
    ldr x1, =newline            // x1 = "\n"
    bl copy_str                 // Copiar salto de línea
    mov x24, x0                 // x24 = nueva posición

    // Línea 2: TOTAL_VALUES=30
    mov x0, x24                 // x0 = posición actual
    ldr x1, =label_total        // x1 = "TOTAL_VALUES="
    bl copy_str                 // Copiar
    mov x24, x0                 // x24 = nueva posición

    mov x0, x24                 // x0 = posición actual
    mov x1, #N_VALUES           // x1 = 30 (cantidad de valores)
    bl utils_i64_to_str         // Convertir número a texto ASCII
    mov x24, x0                 // x24 = nueva posición

    mov x0, x24                 // x0 = posición actual
    ldr x1, =newline            // x1 = "\n"
    bl copy_str                 // Copiar salto
    mov x24, x0                 // x24 = nueva posición

    // Línea 3: MEAN=X (media)
    mov x0, x24                 // x0 = posición actual
    ldr x1, =label_med          // x1 = "MEAN="
    bl copy_str                 // Copiar
    mov x24, x0                 // x24 = nueva posición

    mov x0, x24                 // x0 = posición actual
    mov x1, x19                 // x1 = media
    bl utils_i64_to_str         // Convertir a texto
    mov x24, x0                 // x24 = nueva posición

    mov x0, x24                 // x0 = posición actual
    ldr x1, =newline            // x1 = "\n"
    bl copy_str                 // Copiar salto
    mov x24, x0                 // x24 = nueva posición

    // Línea 4: VARIANCE=X
    mov x0, x24                 // x0 = posición actual
    ldr x1, =label_var          // x1 = "VARIANCE="
    bl copy_str                 // Copiar
    mov x24, x0                 // x24 = nueva posición

    mov x0, x24                 // x0 = posición actual
    mov x1, x22                 // x1 = varianza
    bl utils_i64_to_str         // Convertir a texto
    mov x24, x0                 // x24 = nueva posición

    mov x0, x24                 // x0 = posición actual
    ldr x1, =newline            // x1 = "\n"
    bl copy_str                 // Copiar salto
    mov x24, x0                 // x24 = nueva posición

    // Línea 5: STD_DEV=X (desviación estándar)
    mov x0, x24                 // x0 = posición actual
    ldr x1, =label_desv         // x1 = "STD_DEV="
    bl copy_str                 // Copiar
    mov x24, x0                 // x24 = nueva posición

    mov x0, x24                 // x0 = posición actual
    mov x1, x23                 // x1 = desviación estándar
    bl utils_i64_to_str         // Convertir a texto
    mov x24, x0                 // x24 = nueva posición

    mov x0, x24                 // x0 = posición actual
    ldr x1, =newline            // x1 = "\n"
    bl copy_str                 // Copiar salto
    mov x24, x0                 // x24 = nueva posición

    // ====================================================================
    // PASO 8: CREAR/ABRIR ARCHIVO DE SALIDA Y ESCRIBIR
    // ====================================================================
    ldr x0, =archivo_salida         // x0 = "results/resultado_varianza.txt"
    ldr x1, =buffer_salida          // x1 = dirección del contenido
    ldr x3, =buffer_salida          // x3 = inicio del buffer (para calcular largo)
    sub x2, x24, x3                 // x2 = bytes a escribir (fin - inicio)
    bl utils_write_result           // Crear/truncar y escribir archivo usando utils
    cmp x0, #0                      // Comparar: ¿error?
    blt _exit_error                             // Si error, salir

    // ====================================================================
    // PASO 9: CERRAR ARCHIVOS Y TERMINAR
    // ====================================================================
    ldr x0, =descriptor_csv     // x0 = dirección del ID del CSV
    ldr x0, [x0]                // x0 = ID del archivo CSV
    bl utils_close_csv          // Cerrar CSV usando la biblioteca común

    b _exit_success             // Salir exitosamente

// ========================================================================
// FUNCIÓN: read_line
// Lee una línea de un archivo byte a byte hasta encontrar '\n' o EOF
// Entrada:  x0 = file descriptor (ID del archivo)
//           x1 = dirección del buffer donde guardar
//           x2 = tamaño máximo del buffer
// Salida:   Buffer terminado con '\0'
// ========================================================================
read_line:
    stp x29, x30, [sp, #-16]!   // Guardar registros (prologue)
    mov x29, sp

    mov x3, x0                  // x3 = file descriptor
    mov x4, x1                  // x4 = dirección del buffer
    mov x5, x2                  // x5 = tamaño máximo
    mov x6, #0                  // x6 = contador de bytes leídos

.read_byte_loop:
    cmp x6, x5                  // ¿contador >= tamaño máximo?
    bge .read_line_done         // Si sí, terminar

    sub sp, sp, #16             // Reservar espacio en stack para leer 1 byte
    mov x0, x3                  // x0 = file descriptor
    mov x1, sp                  // x1 = dirección del buffer temporal (1 byte)
    mov x2, #1                  // x2 = leer 1 byte
    mov x8, LEER                // x8 = 63 (syscall LEER)
    svc #0                      // Ejecutar

    ldrb w7, [sp]               // w7 = byte leído
    add sp, sp, #16             // Liberar espacio en stack

    cmp x0, #0                  // ¿Leímos algo? (retorna 0 si EOF)
    beq .read_line_done         // Si no, terminamos

    cmp w7, #'\n'               // ¿Es salto de línea?
    beq .read_line_done         // Si sí, terminar

    strb w7, [x4, x6]           // Guardar byte en buffer[contador]
    add x6, x6, #1              // contador++
    b .read_byte_loop           // Continuar leyendo

.read_line_done:
    strb wzr, [x4, x6]          // Terminar string con '\0'

    ldp x29, x30, [sp], #16     // Restaurar registros (epilogue)
    ret                         // Retornar

// ========================================================================
// FUNCIÓN: parse_csv_column
// Extrae una columna de una línea CSV y la convierte a número entero
// Entrada:  x0 = dirección de la línea
//           x1 = número de columna (0-indexed)
// Salida:   x0 = valor numérico extraído
// ========================================================================
parse_csv_column:
    stp x29, x30, [sp, #-16]!   // Guardar registros

    mov x2, #0                  // x2 = contador de comas (columnas)
    mov x3, #0                  // x3 = valor numérico acumulado
    mov x4, x1                  // x4 = columna buscada

    cmp x4, #0                  // ¿Buscamos columna 0?
    beq .parse_col_digits       // Si sí, saltamos búsqueda de comas

.parse_col_search:
    ldrb w5, [x0]               // w5 = carácter actual
    cmp w5, #0                  // ¿Fin de string?
    beq .parse_col_done         // Si sí, terminamos

    cmp w5, #','                // ¿Es una coma?
    bne .parse_col_next_char    // Si no, siguiente carácter

    add x2, x2, #1              // Incrementar contador de comas
    cmp x2, x4                  // ¿Encontramos nuestra columna?
    beq .parse_col_found        // Si sí, empezar a extraer

.parse_col_next_char:
    add x0, x0, #1              // Siguiente carácter
    b .parse_col_search         // Continuar buscando

.parse_col_found:
    add x0, x0, #1              // Saltamos la coma

.parse_col_digits:
    ldrb w5, [x0]               // w5 = carácter actual
    cmp w5, #0                  // ¿Fin de string?
    beq .parse_col_done         // Si sí, terminamos
    cmp w5, #','                // ¿Otra coma? (fin de columna)
    beq .parse_col_done         // Si sí, terminamos
    cmp w5, #'\n'               // ¿Salto de línea?
    beq .parse_col_done         // Si sí, terminamos

    cmp w5, #'0'                // ¿Menor que '0'?
    blt .parse_col_skip_char    // Si sí, no es dígito
    cmp w5, #'9'                // ¿Mayor que '9'?
    bgt .parse_col_skip_char    // Si sí, no es dígito

    sub w5, w5, #'0'            // Convertir char a número (restar '0')
    mov x6, #10                 // x6 = 10
    mul x3, x3, x6              // x3 = x3 * 10 (agregar lugar)
    add x3, x3, x5              // x3 = x3 + dígito

.parse_col_skip_char:
    add x0, x0, #1              // Siguiente carácter
    b .parse_col_digits         // Continuar extrayendo

.parse_col_done:
    mov x0, x3                  // x0 = valor final

    ldp x29, x30, [sp], #16     // Restaurar registros
    ret                         // Retornar

// ========================================================================
// FUNCIÓN: calcular_media
// Suma todos los 30 valores y divide entre 30 para obtener el promedio
// Entrada:  x0 = dirección del array de temperaturas
// Salida:   x0 = media (como entero)
// ========================================================================
calcular_media:
    stp x29, x30, [sp, #-16]!   // Guardar registros

    mov x1, #0                  // x1 = suma acumulada
    mov x2, #0                  // x2 = contador
    mov x3, x0                  // x3 = dirección del array

.mean_sum_loop:
    cmp x2, #N_VALUES           // ¿Ya sumamos 30 valores?
    bge .mean_divide            // Si sí, ir a dividir

    ldr x4, [x3]                // x4 = array[contador]
    add x1, x1, x4              // suma += x4
    add x3, x3, #8              // Siguiente elemento (8 bytes)
    add x2, x2, #1              // contador++
    b .mean_sum_loop            // Continuar

.mean_divide:
    mov x0, x1                  // x0 = suma total
    mov x1, #N_VALUES           // x1 = 30
    sdiv x0, x0, x1             // x0 = x0 / 30 (división con signo)

    ldp x29, x30, [sp], #16     // Restaurar registros
    ret                         // Retornar

// ========================================================================
// FUNCIÓN: calcular_varianza
// Calcula: Σ(Xi - media)² / N
// Entrada:  x0 = dirección del array
//           x1 = media
// Salida:   x0 = varianza (como entero)
// ========================================================================
calcular_varianza:
    stp x29, x30, [sp, #-16]!   // Guardar registros

    mov x2, #0                  // x2 = suma de cuadrados
    mov x3, #0                  // x3 = contador
    mov x4, x0                  // x4 = dirección del array
    mov x5, x1                  // x5 = media

.var_sum_loop:
    cmp x3, #N_VALUES           // ¿Ya procesamos 30 valores?
    bge .var_divide             // Si sí, ir a dividir

    ldr x6, [x4]                // x6 = array[contador]
    sub x6, x6, x5              // x6 = x6 - media (diferencia)
    mul x6, x6, x6              // x6 = x6 * x6 (elevar al cuadrado)
    add x2, x2, x6              // suma += x6²

    add x4, x4, #8              // Siguiente elemento (8 bytes)
    add x3, x3, #1              // contador++
    b .var_sum_loop             // Continuar

.var_divide:
    mov x0, x2                  // x0 = suma de cuadrados
    mov x1, #N_VALUES           // x1 = 30
    sdiv x0, x0, x1             // x0 = x0 / 30

    ldp x29, x30, [sp], #16     // Restaurar registros
    ret                         // Retornar

// ========================================================================
// FUNCIÓN: isqrt
// Calcula la raíz cuadrada entera usando el método babilónico iterativo
// Entrada:  x0 = número
// Salida:   x0 = raíz cuadrada (truncada)
// ========================================================================
isqrt:
    stp x29, x30, [sp, #-16]!   // Guardar registros

    cmp x0, #0                  // ¿Es cero?
    beq .isqrt_return           // Si sí, retornar 0
    cmp x0, #1                  // ¿Es uno?
    beq .isqrt_return           // Si sí, retornar 1

    mov x3, x0                  // x3 = número original
    mov x1, x0                  // x1 = aproximación inicial (el número mismo)

.isqrt_iter:
    sdiv x2, x3, x1             // x2 = n / x (division)
    add x2, x2, x1              // x2 = (n/x + x)
    lsr x2, x2, #1              // x2 = (n/x + x) / 2 (shift right = div 2)

    cmp x2, x1                  // ¿Nueva aproximación >= anterior?
    bge .isqrt_converged        // Si sí, convergió

    mov x1, x2                  // x1 = nueva aproximación
    b .isqrt_iter               // Iterar de nuevo

.isqrt_converged:
    mov x0, x1                  // x0 = resultado final

.isqrt_return:
    ldp x29, x30, [sp], #16     // Restaurar registros
    ret                         // Retornar

// ========================================================================
// FUNCIÓN: int_to_ascii
// Convierte un número entero a su representación en texto ASCII
// Ej: 42 → "42"
// Entrada:  x0 = dirección del buffer destino
//           x1 = número a convertir
// Salida:   x0 = nueva posición en el buffer
// ========================================================================
int_to_ascii:
    stp x29, x30, [sp, #-16]!   // Guardar registros

    cmp x1, #0                  // ¿Es cero?
    bne .ita_normal             // Si no, ir a conversión normal

    // Caso especial: número es 0
    mov w2, #'0'                // w2 = carácter '0'
    strb w2, [x0]               // Guardar '0' en buffer
    add x0, x0, #1              // Siguiente posición
    b .ita_done                 // Terminar

.ita_normal:
    sub sp, sp, #32             // Reservar 32 bytes en stack
    mov x3, sp                  // x3 = puntero al stack temporal
    mov x4, #0                  // x4 = contador de dígitos

.ita_extract_digits:
    cmp x1, #0                  // ¿Número es 0?
    beq .ita_write_digits       // Si sí, empezar a escribir

    mov x5, #10                 // x5 = 10
    udiv x6, x1, x5             // x6 = número / 10
    msub x7, x6, x5, x1         // x7 = número - (número/10 * 10) = resto

    add w7, w7, #'0'            // Convertir dígito a char ASCII
    strb w7, [x3, x4]           // Guardar dígito en stack
    add x4, x4, #1              // contador++

    mov x1, x6                  // número = número / 10
    b .ita_extract_digits       // Continuar

.ita_write_digits:
    sub x4, x4, #1              // Retroceder al último dígito

.ita_write_loop:
    cmp x4, #-1                 // ¿Escribimos todos?
    beq .ita_restore_sp         // Si sí, restaurar stack

    ldrb w5, [x3, x4]           // w5 = dígito del stack
    strb w5, [x0]               // Guardar en buffer destino
    add x0, x0, #1              // Siguiente posición
    sub x4, x4, #1              // Retroceder
    b .ita_write_loop           // Continuar

.ita_restore_sp:
    add sp, sp, #32             // Liberar espacio en stack

.ita_done:
    ldp x29, x30, [sp], #16     // Restaurar registros
    ret                         // Retornar

// ========================================================================
// FUNCIÓN: copy_str
// Copia un string fuente (terminado en '\0') al buffer destino
// Entrada:  x0 = dirección del buffer destino
//           x1 = dirección del string fuente
// Salida:   x0 = nueva posición en el destino
// ========================================================================
copy_str:
    stp x29, x30, [sp, #-16]!   // Guardar registros

.copy_loop:
    ldrb w2, [x1]               // w2 = carácter del fuente
    cmp w2, #0                  // ¿Es fin de string ('\0')?
    beq .copy_done              // Si sí, terminamos

    strb w2, [x0]               // Guardar carácter en destino
    add x0, x0, #1              // Siguiente posición destino
    add x1, x1, #1              // Siguiente carácter fuente
    b .copy_loop                // Continuar

.copy_done:
    ldp x29, x30, [sp], #16     // Restaurar registros
    ret                         // Retornar

// ========================================================================
// MANEJO DE ERRORES Y SALIDAS
// ========================================================================

// Salida con ERROR (código 1)
_exit_error:
    mov x0, #1                  // x0 = 1 (código de error)
    bl utils_exit               // Ejecutar salida usando utils

// Salida EXITOSA (código 0)
_exit_success:
    mov x0, #0                  // x0 = 0 (éxito)
    bl utils_exit               // Ejecutar salida usando utils
