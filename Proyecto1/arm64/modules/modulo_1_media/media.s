// =============================================================================
// media.s — Módulo 1: Media aritmética ponderada
// Integrante 1 — Grupo 17 — ACYE1 Invernadero Inteligente IoT
// =============================================================================
// Lee la columna TEMP del archivo lecturas.csv (30 datos reales),
// calcula la media ponderada con pesos crecientes W_i = i  (1..30)
// y escribe el resultado en results/resultado_media.txt.
//
// Fórmula (enunciado §10.1):
//     MEDIA_PONDERADA = Σ(X_i * W_i) / ΣW_i
//     con W_i = i   (i = 1..30)   y  ΣW_i = 465
//
// Formato exacto de salida (enunciado §10.1):
//     MODULE=WEIGHTED_MEAN
//     TOTAL_VALUES=30
//     SUM_X=<suma de X_i>
//     WEIGHT_SUM=465
//     WEIGHTED_MEAN=<media entera>
//
// Compilar y ejecutar (en Raspberry Pi 3/4, ruta absoluta):
//     cd Proyecto1/arm64
//     make utils    # objeto compartido (vacio por ahora)
//     make modulo1
//     ./build/modulo_1_media
//     cat results/resultado_media.txt
//
// O con QEMU en PC:
//     make run1
//
// Ensamblador: aarch64-linux-gnu-as
// Enlazador  : aarch64-linux-gnu-ld
// Ejecucion  : qemu-aarch64   (o nativo en Pi)
// =============================================================================

// -----------------------------------------------------------------------------
// Constantes de syscalls (Linux AArch64) y descriptores
// Tomadas de projects/src/constants.inc del repo del auxiliar.
// -----------------------------------------------------------------------------
.equ SYS_READ,        63              // syscall read(fd, buf, count)
.equ SYS_WRITE,       64              // syscall write(fd, buf, count)
.equ SYS_OPENAT,      56              // syscall openat(dirfd, path, flags, mode)
.equ SYS_CLOSE,       57              // syscall close(fd)
.equ SYS_EXIT,        93              // syscall exit(status)

.equ AT_FDCWD,        -100            // directorio actual para openat

.equ O_RDONLY,        0               // flags para openat (solo lectura)
.equ O_WRONLY,        1               // flags para openat (solo escritura)
.equ O_CREAT,         0100            // crear archivo si no existe (octal)
.equ O_TRUNC,         01000           // truncar a 0 si existe (octal)

// -----------------------------------------------------------------------------
// Constantes del módulo (no provistas por enunciado, son propias)
// -----------------------------------------------------------------------------
.equ N_VALUES,        30              // exactamente 30 lecturas
.equ WEIGHT_SUM,      465             // Σ(1..30) = 30*31/2

// =============================================================================
// Sección .rodata — strings de solo lectura (rutas y etiquetas de salida)
// =============================================================================
.section .rodata
.align 3

// Rutas relativas al CWD = arm64/  (donde corre `make run1` o `./build/...`)
csv_path:  .asciz "lecturas.csv"                  // archivo de entrada
out_path:  .asciz "results/resultado_media.txt"   // archivo de salida

// Etiquetas de cada línea del archivo de salida (formato exacto del enunciado)
mod_name:  .asciz "MODULE=WEIGHTED_MEAN\n"
total_v:   .asciz "TOTAL_VALUES=30\n"
lbl_sumx:  .asciz "SUM_X="
lbl_wsum:  .asciz "WEIGHT_SUM=465\n"
lbl_mean:  .asciz "WEIGHTED_MEAN="
nl:        .asciz "\n"

// =============================================================================
// Sección .bss — buffers en memoria no inicializada
// =============================================================================
.section .bss
.align 3

line_buf:    .skip 64                       // buffer para leer 1 línea del CSV
values_buf:  .skip 8 * N_VALUES            // arreglo de 30 enteros (8 bytes c/u)
out_buf:     .skip 256                      // buffer de salida (5 líneas)

// =============================================================================
// Sección .text — código
// =============================================================================
.section .text
.global _start

// -----------------------------------------------------------------------------
// _start — punto de entrada
//   1. Abrir  lecturas.csv             → x19 = fd_entrada
//   2. Leer   30 líneas y parsear col 1 → values_buf[30]
//   3. Cerrar archivo de entrada
//   4. Calcular sum_x  con sum_values
//   5. Calcular mean   con weighted_mean (subrutina propia)
//   6. Construir archivo de salida      → out_buf
//   7. Abrir  results/resultado_media.txt
//   8. Escribir out_buf y cerrar
//   9. exit(0)
//
// Registros de larga vida (callee-saved):
//   x19 = fd actual (entrada o salida)
//   x20 = contador de líneas (en lectura) / longitud de salida
//   x21 = sum_x
//   x22 = weighted_mean
// -----------------------------------------------------------------------------
_start:
    // ---- 1) Abrir lecturas.csv (openat) ----
    mov  x0, #AT_FDCWD                     // x0 = directorio actual
    adr  x1, csv_path                      // x1 = ruta del CSV
    mov  x2, #O_RDONLY                     // x2 = solo lectura
    mov  x3, #0                            // x3 = modo (ignorado en O_RDONLY)
    mov  x8, #SYS_OPENAT                   // x8 = numero de syscall
    svc  #0                                // llamada al kernel
    cmp  x0, #0                            // verifico fd >= 0
    b.lt error_exit                        // si fallo, salgo con codigo 1
    mov  x19, x0                           // x19 = fd de entrada

    // ---- 2) Leer 30 líneas y parsear la columna 1 (TEMP) ----
    mov  x20, #0                           // x20 = i = 0
read_loop:
    cmp  x20, #N_VALUES                    // ¿ya leí 30?
    b.ge read_done                         // si, salir del loop
    // ---- leer una linea del CSV ----
    mov  x0, x19                           // x0 = fd
    adr  x1, line_buf                      // x1 = buffer destino
    mov  x2, #64                           // x2 = capacidad
    mov  x8, #SYS_READ                     // syscall read
    svc  #0
    cmp  x0, #0                            // ¿se leyo algo?
    b.le read_done                         // EOF o error, salir
    // ---- parsear columna 1 (TEMP) de la línea ----
    adr  x0, line_buf                      // x0 = buffer de la linea
    mov  x1, #1                            // x1 = columna objetivo (0=ID, 1=TEMP)
    bl   parse_csv_column                  // x0 = valor entero parseado
    // ---- guardar en values_buf[i] ----
    adr  x9, values_buf                    // x9 = base del arreglo
    lsl  x10, x20, #3                      // x10 = i * 8  (offset en bytes)
    str  x0, [x9, x10]                     // values_buf[i] = x0
    add  x20, x20, #1                      // i++
    b    read_loop                         // siguiente linea

read_done:
    // ---- 3) Cerrar archivo de entrada ----
    mov  x0, x19                           // x0 = fd
    mov  x8, #SYS_CLOSE                    // syscall close
    svc  #0

    // ---- 4) Calcular sum_x  (Σ X_i) ----
    adr  x0, values_buf                    // x0 = base del arreglo
    bl   sum_values                        // x0 = sum_x
    mov  x21, x0                           // x21 = sum_x

    // ---- 5) Calcular weighted_mean  (Σ X_i*W_i / 465) ----
    adr  x0, values_buf                    // x0 = base del arreglo
    bl   weighted_mean                     // x0 = media entera
    mov  x22, x0                           // x22 = mean

    // ---- 6) Construir archivo de salida en out_buf ----
    adr  x9, out_buf                       // x9 = cursor de salida

    // linea 1: "MODULE=WEIGHTED_MEAN\n"
    adr  x0, mod_name
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // linea 2: "TOTAL_VALUES=30\n"
    adr  x0, total_v
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // linea 3: "SUM_X=<sum_x>\n"
    adr  x0, lbl_sumx
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x21                           // valor = sum_x
    mov  x1, x9
    bl   int_to_ascii                      // convierte y avanza cursor
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // linea 4: "WEIGHT_SUM=465\n"
    adr  x0, lbl_wsum
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // linea 5: "WEIGHTED_MEAN=<mean>\n"
    adr  x0, lbl_mean
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x22                           // valor = mean
    mov  x1, x9
    bl   int_to_ascii
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // longitud total escrita = x9 - out_buf
    adr  x10, out_buf
    sub  x23, x9, x10                      // x23 = longitud del buffer

    // ---- 7) Abrir results/resultado_media.txt para escritura ----
    mov  x0, #AT_FDCWD
    adr  x1, out_path
    mov  x2, #O_WRONLY | O_CREAT | O_TRUNC // crear y truncar
    mov  x3, #0644                         // permisos rw-r--r--
    mov  x8, #SYS_OPENAT
    svc  #0
    cmp  x0, #0
    b.lt error_exit
    mov  x19, x0                           // x19 = fd de salida

    // ---- 8) Escribir buffer completo ----
    mov  x0, x19                           // x0 = fd
    adr  x1, out_buf                       // x1 = buffer
    mov  x2, x23                           // x2 = longitud
    mov  x8, #SYS_WRITE                    // syscall write
    svc  #0

    // cerrar archivo de salida
    mov  x0, x19
    mov  x8, #SYS_CLOSE
    svc  #0

    // ---- 9) Salir con éxito ----
    mov  x0, #0                            // codigo de salida = 0
    mov  x8, #SYS_EXIT
    svc  #0

error_exit:
    mov  x0, #1                            // codigo de salida = 1
    mov  x8, #SYS_EXIT
    svc  #0

// =============================================================================
// parse_csv_column — extrae el valor entero de la columna N de una línea CSV
// -----------------------------------------------------------------------------
// Entradas:
//   x0 = puntero al inicio de la línea (terminada en '\n' o '\0')
//   x1 = índice de la columna (0 = ID, 1 = TEMP, 2 = HUM_AIRE, ...)
// Salida:
//   x0 = valor entero de la columna solicitada (0 si EOF/inválido)
//
// Procedimiento:
//   1. Avanzar por campos hasta llegar a la columna objetivo
//      (cada campo termina en ','; el último termina en '\n' o '\0')
//   2. Acumular dígitos decimales hasta encontrar delimitador
// =============================================================================
parse_csv_column:
    stp  x29, x30, [sp, #-16]!            // prologo: guardar fp/lr
    mov  x29, sp
    mov  x2, x0                            // x2 = cursor de lectura
    mov  x3, x1                            // x3 = columna objetivo
    mov  x4, #0                            // x4 = columna actual

parse_skip_outer:
    cmp  x4, x3                            // ¿llegamos a la columna objetivo?
    b.ge parse_read_int                    // si, empezar a leer el entero
parse_skip_field:                          // sino, saltar el campo actual
    ldrb w5, [x2]                          // cargar byte actual
    cbz  w5, parse_eof                     // si es NUL, fin de string
    cmp  w5, #'\n'                         // si es newline, fin de linea
    b.eq parse_eof
    cmp  w5, #','                          // si es coma, fin de campo
    b.ne parse_skip_next                   // si no, seguir avanzando
    add  x2, x2, #1                        // avanzar mas alla de la coma
    add  x4, x4, #1                        // incrementar columna actual
    b    parse_skip_outer                  // evaluar de nuevo
parse_skip_next:
    add  x2, x2, #1                        // siguiente byte
    b    parse_skip_field

parse_read_int:
    // x2 apunta al primer dígito de la columna objetivo
    mov  x0, #0                            // acumulador = 0
    mov  x6, #10                           // base decimal
parse_digit:
    ldrb w5, [x2]                          // cargar byte
    cmp  w5, #'0'                          // ¿es dígito?
    b.lt parse_done
    cmp  w5, #'9'
    b.gt parse_done
    mul  x0, x0, x6                        // acc = acc * 10
    sub  w5, w5, #'0'                      // convertir ASCII a numero
    add  x0, x0, x5                        // acc = acc + digito
    add  x2, x2, #1                        // siguiente byte
    b    parse_digit

parse_eof:
    mov  x0, #0                            // EOF → 0
parse_done:
    ldp  x29, x30, [sp], #16               // epilogo
    ret

// =============================================================================
// sum_values — suma los N_VALUES enteros (i64) de un arreglo
// -----------------------------------------------------------------------------
// Entradas:
//   x0 = puntero al arreglo
// Salida:
//   x0 = suma total (puede ser grande; entra en i64)
//
// Procedimiento:
//   acc = 0
//   for i in 0..29:
//       acc += values[i]
//   return acc
// =============================================================================
sum_values:
    stp  x29, x30, [sp, #-16]!            // prologo
    mov  x29, sp
    mov  x1, x0                            // x1 = base del arreglo
    mov  x2, #0                            // x2 = i = 0
    mov  x3, #0                            // x3 = acc = 0
sum_loop:
    cmp  x2, #N_VALUES                     // ¿llegamos al final?
    b.ge sum_done
    ldr  x4, [x1, x2, lsl #3]              // x4 = values[i]  (carga 8 bytes)
    add  x3, x3, x4                        // acc += values[i]
    add  x2, x2, #1                        // i++
    b    sum_loop
sum_done:
    mov  x0, x3                            // retornar acc
    ldp  x29, x30, [sp], #16               // epilogo
    ret

// =============================================================================
// weighted_mean — SUBRUTINA PROPIA (requisito enunciado §9.3 #10)
// -----------------------------------------------------------------------------
// Calcula la media aritmética ponderada entera:
//   mean = Σ (X_i * (i+1)) / Σ(i=1..30)
//        = Σ (X_i * (i+1)) / 465
//
// Entradas:
//   x0 = puntero al arreglo de N_VALUES enteros (8 bytes c/u)
// Salida:
//   x0 = media ponderada (división entera con truncamiento hacia 0)
//
// Procedimiento:
//   acc = 0
//   for i in 0..29:
//       weight = i + 1
//       acc += values[i] * weight
//   return acc / 465  (sdiv = división con signo, trunca hacia 0)
//
// Registros:
//   x1 = base del arreglo
//   x2 = índice i
//   x3 = acumulador acc_weighted
//   x4 = value temporal values[i]
//   x5 = peso (i+1)
// =============================================================================
weighted_mean:
    stp  x29, x30, [sp, #-16]!            // prologo
    mov  x29, sp
    mov  x1, x0                            // x1 = base del arreglo
    mov  x2, #0                            // x2 = i = 0
    mov  x3, #0                            // x3 = acc_weighted = 0
wm_loop:
    cmp  x2, #N_VALUES                     // ¿procesamos los 30?
    b.ge wm_done
    ldr  x4, [x1, x2, lsl #3]              // x4 = values[i]
    add  x5, x2, #1                        // x5 = peso = i + 1
    mul  x4, x4, x5                        // x4 = values[i] * peso
    add  x3, x3, x4                        // acc += ...
    add  x2, x2, #1                        // i++
    b    wm_loop
wm_done:
    mov  x4, #WEIGHT_SUM                   // x4 = 465
    sdiv x0, x3, x4                        // x0 = acc / 465 (división entera)
    ldp  x29, x30, [sp], #16               // epilogo
    ret

// =============================================================================
// int_to_ascii — convierte un entero no-negativo a su representación ASCII
// -----------------------------------------------------------------------------
// Entradas:
//   x0 = valor (>= 0, hasta 64 bits)
//   x1 = puntero al buffer destino
// Salida:
//   x0 = puntero al siguiente byte libre en el buffer
//
// Procedimiento:
//   1. Caso especial: si valor == 0, escribir '0' y terminar.
//   2. Extraer dígitos del menos significativo al más (división por 10),
//      almacenándolos temporalmente en la pila.
//   3. Copiar los dígitos en orden inverso al buffer destino.
// =============================================================================
int_to_ascii:
    stp  x29, x30, [sp, #-32]!            // prologo
    mov  x29, sp
    stp  x19, x20, [sp, #16]               // guardar x19/x20
    mov  x19, x0                           // x19 = valor
    mov  x20, x1                           // x20 = buffer destino

    cbnz x19, itoa_non_zero                // si valor != 0, continuar
    // caso especial: valor = 0
    mov  w0, #'0'                          // escribir '0'
    strb w0, [x20]
    add  x0, x20, #1                       // retornar puntero avanzado
    b    itoa_done

itoa_non_zero:
    sub  sp, sp, #32                       // reservar buffer temporal en pila
    mov  x2, sp                            // x2 = base del buffer temporal
    mov  x3, #0                            // x3 = contador de dígitos
    mov  x4, #10                           // x4 = divisor
itoa_digit:
    udiv x5, x19, x4                       // x5 = cociente
    msub x6, x5, x4, x19                   // x6 = x19 - x5*10 = residuo
    add  x6, x6, #'0'                      // x6 = caracter ASCII del dígito
    strb w6, [x2, x3]                      // guardar en buffer temporal
    add  x3, x3, #1                        // contador++
    mov  x19, x5                           // valor = cociente
    cbnz x19, itoa_digit                   // repetir mientras cociente != 0

    // copiar dígitos al destino en orden INVERSO (MSB primero)
    mov  x7, #0                            // x7 = índice de copia
itoa_copy:
    ldrb w6, [x2, x7]                      // cargar dígito del buffer temporal
    strb w6, [x20, x7]                     // escribir en buffer destino
    add  x7, x7, #1                        // índice++
    sub  x3, x3, #1                        // decrementar contador
    cbnz x3, itoa_copy                     // repetir hasta copiar todos

    add  sp, sp, #32                       // liberar buffer temporal
    add  x0, x20, x7                       // x0 = destino + bytes escritos
itoa_done:
    ldp  x19, x20, [sp, #16]               // restaurar x19/x20
    ldp  x29, x30, [sp], #32               // epilogo
    ret

// =============================================================================
// copy_str — copia un string ASCIIZ (terminado en NUL) a un buffer
// -----------------------------------------------------------------------------
// Entradas:
//   x0 = puntero al string origen (NUL-terminated)
//   x1 = puntero al buffer destino
// Salida:
//   x0 = puntero al byte NUL copiado (lugar donde se escribió el terminador)
//
// Procedimiento:
//   mientras *src != 0:
//       *dst = *src
//       src++;  dst++
// =============================================================================
copy_str:
copy_str_loop:
    ldrb w2, [x0]                          // cargar byte del origen
    cbz  w2, copy_str_done                 // si es NUL, terminar
    strb w2, [x1]                          // escribir en destino
    add  x0, x0, #1                        // src++
    add  x1, x1, #1                        // dst++
    b    copy_str_loop
copy_str_done:
    // x0 queda apuntando al NUL copiado; x1 quedó una posición más allá
    // (no se usa x1, así que da igual)
    ret
