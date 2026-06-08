// =============================================================================
// predicciones.s — Módulo 4: Predicción Lineal Simple
// Integrante 4 — Grupo 17 — ACYE1 Invernadero Inteligente IoT
// =============================================================================
// Lee la columna TEMP del archivo lecturas.csv (30 datos reales),
// calcula la predicción simple usando punto fijo ×100 y escribe el resultado
// en results/resultado_prediccion.txt.
//
// Fórmulas (enunciado §10.4):
//   DIF = X_FINAL - X_INICIAL
//   PROMEDIO_CAMBIO = DIF / (N - 1)          → en punto fijo: (DIF * 100) / 29
//   PREDICCION = X_FINAL + PROMEDIO_CAMBIO   → en punto fijo: final*100 + avg_fp
//
// Formato EXACTO de salida (enunciado §10.4, sin espacios alrededor de =):
//     MODULE=PREDICTION
//     TOTAL_VALUES=30
//     INITIAL_VALUE=<values[0]>
//     FINAL_VALUE=<values[29]>
//     TOTAL_DIFF=<diff>
//     AVG_CHANGE=<entero.decimal>     (2 decimales, ej: 0.27)
//     NEXT_VALUE=<entero.decimal>     (2 decimales, ej: 30.27)
//
// Compilar y ejecutar (Raspberry Pi 3/4 nativo):
//     cd Proyecto1/arm64
//     make modulo4
//     ./build/modulo_4_prediccion
//     cat results/resultado_prediccion.txt
//
// Con QEMU en PC (sin Raspberry Pi):
//     make run4
//
// Ensamblador: aarch64-linux-gnu-as
// Enlazador  : aarch64-linux-gnu-ld
// Ejecución  : qemu-aarch64 (o nativo en Pi)
// =============================================================================

// ---------------------------------------------------------------------------
// Constantes de syscalls Linux AArch64
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Constantes del módulo
// ---------------------------------------------------------------------------
.equ N_VALUES,        30

// =============================================================================
// .rodata — strings de solo lectura
// =============================================================================
.section .rodata
.align 3

csv_path:   .asciz "lecturas.csv"
out_path:   .asciz "results/resultado_prediccion.txt"

// Etiquetas de salida (formato EXACTO del enunciado §10.4)
lbl_module: .asciz "MODULE=PREDICTION\n"
lbl_total:  .asciz "TOTAL_VALUES=30\n"
lbl_init:   .asciz "INITIAL_VALUE="
lbl_final:  .asciz "FINAL_VALUE="
lbl_diff:   .asciz "TOTAL_DIFF="
lbl_avg:    .asciz "AVG_CHANGE="
lbl_next:   .asciz "NEXT_VALUE="
nl:         .asciz "\n"

// =============================================================================
// .bss — buffers en memoria no inicializada
// =============================================================================
.section .bss
.align 3

line_buf:    .skip 64                 // buffer para 1 línea del CSV
values_buf:  .skip 8 * N_VALUES      // arreglo de 30 enteros i64
out_buf:     .skip 512                // buffer de salida completo

next_value_store:
    .skip 8
// =============================================================================
// .text — código
// =============================================================================
.section .text
.global _start

// ---------------------------------------------------------------------------
// _start — punto de entrada
//
// Registros callee-saved (preservados entre llamadas):
//   x19 = fd actual (entrada o salida)
//   x20 = contador de líneas leídas
//   x21 = initial_value (values[0])
//   x22 = final_value   (values[29])
//   x23 = diff (final - initial)
//   x24 = avg_change_fp  (punto fijo ×100 = (diff * 100) / 29)
//   x25 = next_value_fp  (punto fijo ×100 = final*100 + avg_change_fp)
//   x26 = cursor en out_buf (puntero que avanza al construir la salida)
// ---------------------------------------------------------------------------
_start:
    // ---- 1) Abrir lecturas.csv (openat) ----
    mov  x0, #AT_FDCWD                // directorio actual
    adr  x1, csv_path                 // ruta del CSV
    mov  x2, #O_RDONLY                // solo lectura
    mov  x3, #0                       // modo (ignorado en O_RDONLY)
    mov  x8, #SYS_OPENAT
    svc  #0
    cmp  x0, #0
    b.lt error_exit                   // si fd < 0, error
    mov  x19, x0                      // x19 = fd de entrada

    // ---- 2) Saltar la línea de cabecera del CSV ----
skip_header:
    mov  x0, x19
    adr  x1, line_buf
    mov  x2, #1                       // leer 1 byte
    mov  x8, #SYS_READ
    svc  #0
    cmp  x0, #0
    b.le read_done                    // EOF
    ldrb w6, [x1]                     // w6 = byte leído
    cmp  w6, #'\n'
    b.ne skip_header                  // seguir hasta encontrar \n
    // ---- 3) Leer 30 líneas y parsear columna TEMP (col=1) ----
    mov  x20, #0                      // x20 = contador i = 0
read_loop:
    cmp  x20, #N_VALUES
    b.ge read_done

    // Leer una línea completa byte a byte hasta \n
    mov  x5, #0                       // x5 = índice en line_buf
read_line_loop:
    mov  x0, x19
    adr  x1, line_buf
    add  x1, x1, x5                   // x1 = line_buf + x5
    mov  x2, #1
    mov  x8, #SYS_READ
    svc  #0
    cmp  x0, #0
    b.le read_done                    // EOF inesperado
    ldrb w6, [x1]
    cmp  w6, #'\n'
    b.eq parse_line                   // fin de línea → parsear
    add  x5, x5, #1
    cmp  x5, #63
    b.lt read_line_loop
    b    read_line_loop               // línea muy larga (caso raro)

parse_line:
    mov  w6, #0
    adr  x7, line_buf
    add  x7, x7, x5
    strb w6, [x7]

    adr  x0, line_buf
    mov  x1, #1
    bl   parse_csv_column

    // Guardar en values_buf[i]
    adr  x9, values_buf
    lsl  x10, x20, #3                 // offset = i * 8
    str  x0, [x9, x10]
    add  x20, x20, #1
    b    read_loop

read_done:
    // ---- 4) Cerrar archivo de entrada ----
    mov  x0, x19
    mov  x8, #SYS_CLOSE
    svc  #0

    // ---- 5) Extraer initial, final y calcular diff ----
    adr  x9, values_buf
    ldr  x21, [x9]                    // x21 = initial = values[0]
    ldr  x22, [x9, #(29*8)]           // x22 = final = values[29]
    sub  x23, x22, x21                // x23 = diff = final - initial


     // ---- 6) AVG_CHANGE = (diff * 100) / 29 ----

    mov  x0, #100
    mul  x24, x23, x0      // x24 = diff * 100

    mov  x0, #29
    sdiv x24, x24, x0      // x24 = (diff*100)/29

    // ---- 7) NEXT_VALUE = final*100 + avg_change ----

    mov  x0, #100
    mul  x25, x22, x0

    add  x25, x25, x24

    adr  x9, next_value_store
    str  x25, [x9]

    // ---- 8) Construir buffer de salida en out_buf ----
    adr  x26, out_buf                 // x26 = cursor de escritura


    // Línea 1: "MODULE=PREDICTION\n"
    adr  x0, lbl_module
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // Línea 2: "TOTAL_VALUES=30\n"
    adr  x0, lbl_total
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // Línea 3: "INITIAL_VALUE=<initial>\n"
    adr  x0, lbl_init
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    mov  x0, x21
    mov  x1, x26
    bl   int_to_ascii
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // Línea 4: "FINAL_VALUE=<final>\n"
    adr  x0, lbl_final
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    mov  x0, x22
    mov  x1, x26
    bl   int_to_ascii
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // Línea 5: "TOTAL_DIFF=<diff>\n"
    adr  x0, lbl_diff
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    mov  x0, x23
    mov  x1, x26
    bl   int_to_ascii
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // Línea 6: "AVG_CHANGE=<entero.decimal>\n" (2 decimales, punto fijo)
    adr  x0, lbl_avg
    mov  x1, x26
    bl   copy_str


    mov  x26, x0
    mov  x0, x24                      // x0 = avg_change_fp
    mov  x1, x26
    bl   format_fixed_point           // SUBRUTINA PROPIA
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // Línea 7: "NEXT_VALUE=<entero.decimal>\n"

    adr  x0, lbl_next
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    adr  x9, next_value_store
    ldr  x0, [x9]

    mov  x1, x26
    bl   format_fixed_point
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // ---- 9) Calcular longitud total del buffer ----
    adr  x10, out_buf
    sub  x27, x26, x10                // x27 = bytes a escribir

    // ---- 10) Abrir results/resultado_prediccion.txt (escritura) ----
    mov  x0, #AT_FDCWD
    adr  x1, out_path
    mov x2, #577
    mov  x3, #0644                    // permisos rw-r--r--
    mov  x8, #SYS_OPENAT
    svc  #0
    cmp  x0, #0
    b.lt error_exit
    mov  x19, x0                      // x19 = fd de salida

    // ---- 11) Escribir buffer completo y cerrar ----
    mov  x0, x19
    adr  x1, out_buf
    mov  x2, x27
    mov  x8, #SYS_WRITE
    svc  #0

    mov  x0, x19
    mov  x8, #SYS_CLOSE
    svc  #0

    // ---- 12) exit(0) ----
    mov  x0, #0
    mov  x8, #SYS_EXIT
    svc  #0

error_exit:
    mov  x0, #1                       // código de error = 1
    mov  x8, #SYS_EXIT
    svc  #0


// =============================================================================
// format_fixed_point — SUBRUTINA PROPIA (requisito enunciado §9.3 #10)
// ---------------------------------------------------------------------------
// Convierte un valor en punto fijo ×100 a formato "entero.decimal" con 2 decimales.
// Ejemplos:
//   27   → "0.27"    (AVG_CHANGE cuando diff=8)
//   3027 → "30.27"   (NEXT_VALUE cuando final=30, diff=8)
//   200  → "2.00"
//   5    → "0.05"
//
// Entradas:
//   x0 = valor en punto fijo (puede ser negativo)
//   x1 = puntero al buffer destino
// Salida:
//   x0 = puntero al siguiente byte libre en el buffer
// =============================================================================
format_fixed_point:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    stp  x19, x20, [sp, #-16]!        // Guarda x19, x20

    mov  x19, x0                      // x19 = valor fp (debe ser 3027)
    mov  x20, x1                      // x20 = destino

    cmp  x19, #0
    b.ge fpf_positive
    mov  w0, #'-'
    strb w0, [x20]
    add  x20, x20, #1
    neg  x19, x19

fpf_positive:
    mov  x0, #100
    udiv x2, x19, x0                  // x2 = parte entera = 3027/100 = 30
    msub x3, x2, x0, x19              // x3 = decimal = 3027 - 30*100 = 27
    mov x21, x3

    mov  x0, x2
    mov  x1, x20
    bl   int_to_ascii                 // Imprime "30"
    mov  x20, x0

    mov  w0, #'.'
    strb w0, [x20]
    add  x20, x20, #1

    cmp  x21, #10
    b.ge fpf_decimal_digits
    mov  w0, #'0'
    strb w0, [x20]
    add  x20, x20, #1

fpf_decimal_digits:
    mov  x0, x21                      // x0 = 27
    mov  x1, x20
    bl   int_to_ascii                 // Imprime "27"
    mov  x20, x0

    mov  x0, x20                      // retorna puntero
    ldp  x19, x20, [sp], #16
    ldp  x29, x30, [sp], #16
    ret


// =============================================================================
// parse_csv_column — extrae el valor entero de la columna N de una línea CSV
// ---------------------------------------------------------------------------
// Entradas:
//   x0 = puntero al inicio de la línea (terminada en '\n' o '\0')
//   x1 = índice de la columna (0=ID, 1=TEMP, 2=HUM_AIRE, ...)
// Salida:
//   x0 = valor entero de la columna solicitada (0 si EOF/inválido)
// =============================================================================
parse_csv_column:
    stp  x29, x30, [sp, #-16]!        // prólogo
    mov  x29, sp
    mov  x2, x0                       // x2 = cursor de lectura
    mov  x3, x1                       // x3 = columna objetivo
    mov  x4, #0                       // x4 = columna actual

parse_skip_outer:
    cmp  x4, x3
    b.ge parse_read_int               // llegamos a la columna objetivo
parse_skip_field:
    ldrb w5, [x2]
    cbz  w5, parse_eof                // fin de string
    cmp  w5, #'\n'
    b.eq parse_eof                    // fin de línea
    cmp  w5, #','
    b.ne parse_skip_next              // no es coma, seguir avanzando
    add  x2, x2, #1                   // saltar la coma
    add  x4, x4, #1                   // incrementar columna actual
    b    parse_skip_outer
parse_skip_next:
    add  x2, x2, #1
    b    parse_skip_field

parse_read_int:
    mov  x0, #0                       // acumulador = 0
    mov  x6, #10                      // base decimal
parse_digit:
    ldrb w5, [x2]
    cmp  w5, #'0'
    b.lt parse_done                   // no es dígito, terminar
    cmp  w5, #'9'
    b.gt parse_done                   // no es dígito, terminar
    mul  x0, x0, x6                   // acc = acc * 10
    sub  w5, w5, #'0'                 // convertir ASCII a número
    add  x0, x0, x5                   // acc = acc + dígito
    add  x2, x2, #1
    b    parse_digit

parse_eof:
    mov  x0, #0
parse_done:
    ldp  x29, x30, [sp], #16          // epílogo
    ret


// =============================================================================
// int_to_ascii — convierte un entero no-negativo a su representación ASCII
// ---------------------------------------------------------------------------
// Entradas:
//   x0 = valor entero (>= 0, hasta 64 bits)
//   x1 = puntero al buffer destino
// Salida:
//   x0 = puntero al siguiente byte libre en el buffer
// =============================================================================
int_to_ascii:
    stp  x29, x30, [sp, #-32]!        // prólogo
    mov  x29, sp
    stp  x19, x20, [sp, #16]          // guardar x19, x20
    mov  x19, x0                      // x19 = valor
    mov  x20, x1                      // x20 = destino

    cbnz x19, itoa_non_zero
    mov  w0, #'0'                     // caso especial: valor = 0
    strb w0, [x20]
    add  x0, x20, #1
    b    itoa_done

itoa_non_zero:
    sub  sp, sp, #32                  // reservar buffer temporal en pila
    mov  x2, sp                       // x2 = base del buffer temporal
    mov  x3, #0                       // x3 = contador de dígitos
    mov  x4, #10                      // x4 = divisor
itoa_digit:
    udiv x5, x19, x4                  // x5 = cociente
    msub x6, x5, x4, x19              // x6 = residuo = valor - cociente*10
    add  x6, x6, #'0'                 // convertir a ASCII
    strb w6, [x2, x3]                 // guardar en buffer temporal
    add  x3, x3, #1
    mov  x19, x5                      // valor = cociente
    cbnz x19, itoa_digit              // repetir mientras cociente != 0

    // Copiar dígitos en orden inverso (MSB primero)
    mov  x7, #0                       // x7 = índice de destino
itoa_copy:
    sub  x3, x3, #1
    ldrb w6, [x2, x3]
    strb w6, [x20, x7]
    add  x7, x7, #1
    cbnz x3, itoa_copy

    add  sp, sp, #32                  // liberar buffer temporal
    add  x0, x20, x7                  // retornar puntero avanzado
itoa_done:
    ldp  x19, x20, [sp, #16]          // restaurar x19, x20
    ldp  x29, x30, [sp], #32          // epílogo
    ret


// =============================================================================
// copy_str — copia un string ASCIIZ (terminado en NUL) a un buffer
// ---------------------------------------------------------------------------
// Entradas:
//   x0 = puntero al string origen (NUL-terminated)
//   x1 = puntero al buffer destino
// Salida:
//   x0 = puntero al byte NUL copiado (siguiente byte libre)
// =============================================================================
copy_str:
copy_str_loop:
    ldrb w2, [x0]                     // cargar byte del origen
    cbz  w2, copy_str_done            // si es NUL, terminar
    strb w2, [x1]                     // escribir en destino
    add  x0, x0, #1                   // src++
    add  x1, x1, #1                   // dst++
    b    copy_str_loop
copy_str_done:
    mov  x0, x1                       // retornar destino (siguiente libre)
    ret
