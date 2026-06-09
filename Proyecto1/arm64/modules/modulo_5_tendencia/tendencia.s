// =============================================================================
// tendencia.s — Módulo 5: Tendencia acumulada avanzada
// Integrante 5 — Grupo 17 — ACYE1 Invernadero Inteligente IoT
// =============================================================================
// Lee la columna TEMP del archivo lecturas.csv (30 datos reales),
// calcula métricas de tendencia acumulada (incrementos, decrementos,
// rachas, diferencia acumulada y dirección de tendencia) y escribe
// el resultado en results/resultado_tendencia.txt.
//
// ─────────────────────────────────────────────────────────────────────
// NOTA DE AUTO-CONTENCIÓN TEMPORAL
// ─────────────────────────────────────────────────────────────────────
// Esta versión es temporalmente auto-contenida siguiendo el patrón de
// media.s. Cuando utils.s esté implementado, este módulo deberá
// reemplazar el bloque de lectura/parsing (secciones 1-4 de _start)
// por una llamada a:
//
//     bl   utils_open_csv         // abrir lecturas.csv
//     bl   utils_read_int_column  // leer col TEMP → values_buf[30]
//     bl   utils_close_csv        // cerrar fd
//
// y solo conservar compute_tendency como rutina propia del módulo.
//
// Las subrutinas locales que deberían migrar a utils.s son:
//   - parse_csv_column  → utils_read_int_column (lectura + parsing)
//   - int_to_ascii      → utils_print_i64 (conversión entero → ASCII)
//   - copy_str          → (utilidad genérica de strings)
//
// El bloque de escritura del resultado (secciones 7-9 de _start) también
// debería reemplazarse por:
//     bl   utils_write_result
// ─────────────────────────────────────────────────────────────────────
//
// Cálculo implementado por compute_tendency:
//   Para i = 1..29:
//     DIF_i = X_i - X_(i-1)
//     ACCUM_DIFF += DIF_i
//     si DIF_i > 0: INCREMENTS++, curr_up++, curr_down=0
//     si DIF_i < 0: DECREMENTS++, curr_down++, curr_up=0
//     si DIF_i = 0: curr_up=0, curr_down=0
//     Actualizar MAX_UP_STREAK y MAX_DOWN_STREAK en cada paso.
//
//   TREND = "UP" si ACCUM_DIFF > 0
//           "DOWN" si ACCUM_DIFF < 0
//           "STABLE" si ACCUM_DIFF == 0
//
// Formato exacto de salida (resultado_tendencia.txt):
//   MODULE=ADVANCED_TREND
//   TOTAL_VALUES=30
//   INCREMENTS=<valor>
//   DECREMENTS=<valor>
//   MAX_UP_STREAK=<valor>
//   MAX_DOWN_STREAK=<valor>
//   ACCUM_DIFF=<valor>
//   TREND=<UP|DOWN|STABLE>
//
// Compilar y ejecutar:
//   cd Proyecto1/arm64
//   make modulo5
//   make run5
//   cat results/resultado_tendencia.txt
//
// Depuración con GDB:
//   make gdb5
//   (en otra terminal)
//   gdb-multiarch build/modulo_5_tendencia
//   set architecture aarch64
//   target remote :1234
//   break _start
//   break compute_tendency
//   continue
//   info registers
//   print/x $x20   // INCREMENTS
//   print/x $x21   // DECREMENTS
//   print/x $x22   // MAX_UP_STREAK
//   print/x $x23   // MAX_DOWN_STREAK
//   print/x $x24   // ACCUM_DIFF
//
// Ensamblador: aarch64-linux-gnu-as
// Enlazador  : aarch64-linux-gnu-ld
// Ejecución  : qemu-aarch64  (o nativo en Pi)
// =============================================================================

// -----------------------------------------------------------------------------
// Constantes de syscalls (Linux AArch64) y descriptores
// Idénticas a media.s — cuando utils.s esté listo, usar .extern
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
// Constantes del módulo
// -----------------------------------------------------------------------------
.equ N_VALUES,        30              // exactamente 30 lecturas
.equ TARGET_COL,      1               // columna por defecto = TEMP
                                      // Convención de columnas:
                                      //   0 = ID
                                      //   1 = TEMP        ← por defecto
                                      //   2 = HUM_AIRE
                                      //   3 = HUM_SUELO_1
                                      //   4 = HUM_SUELO_2
                                      //   5 = LUZ
                                      //   6 = GAS
                                      //   7 = RIEGO_1
                                      //   8 = RIEGO_2

// =============================================================================
// Sección .rodata — strings de solo lectura (rutas y etiquetas de salida)
// =============================================================================
.section .rodata
.align 3

// Rutas relativas al CWD = arm64/  (donde corre `make run5` o `./build/...`)
csv_path:      .asciz "lecturas.csv"                       // archivo de entrada
out_path:      .asciz "results/resultado_tendencia.txt"    // archivo de salida

// Etiquetas para el archivo de salida (formato exacto del enunciado)
lbl_module:    .asciz "MODULE=ADVANCED_TREND\n"
lbl_total:     .asciz "TOTAL_VALUES=30\n"
lbl_incr:      .asciz "INCREMENTS="
lbl_decr:      .asciz "DECREMENTS="
lbl_maxup:     .asciz "MAX_UP_STREAK="
lbl_maxdn:     .asciz "MAX_DOWN_STREAK="
lbl_accum:     .asciz "ACCUM_DIFF="
lbl_trend:     .asciz "TREND="
// Valores posibles de TREND
str_up:        .asciz "UP"
str_down:      .asciz "DOWN"
str_stable:    .asciz "STABLE"
nl:            .asciz "\n"

// Signo negativo para ACCUM_DIFF negativo
minus_sign:    .asciz "-"

// =============================================================================
// Sección .bss — buffers en memoria no inicializada
// =============================================================================
.section .bss
.align 3

line_buf:      .skip 128                       // buffer para leer 1 línea del CSV
values_buf:    .skip 8 * N_VALUES              // arreglo de 30 enteros (8 bytes c/u)
out_buf:       .skip 512                       // buffer de salida (8 líneas)

// =============================================================================
// Sección .text — código ejecutable
// =============================================================================
.section .text
.global _start

// -----------------------------------------------------------------------------
// _start — punto de entrada principal
// -----------------------------------------------------------------------------
// Flujo:
//   1. Abrir  lecturas.csv             → x19 = fd_entrada
//   2. Saltar línea de cabecera
//   3. Leer   30 líneas y parsear col TARGET_COL → values_buf[30]
//   4. Cerrar archivo de entrada
//   5. Llamar compute_tendency         → x20..x24 = resultados
//   6. Construir archivo de salida     → out_buf
//   7. Abrir  results/resultado_tendencia.txt
//   8. Escribir out_buf y cerrar
//   9. exit(0)
//
// Registros de larga vida (callee-saved):
//   x19 = fd actual (entrada o salida)
//   x20 = INCREMENTS   (después de compute_tendency)
//   x21 = DECREMENTS   (después de compute_tendency)
//   x22 = MAX_UP_STREAK (después de compute_tendency)
//   x23 = MAX_DOWN_STREAK (después de compute_tendency)
//   x24 = ACCUM_DIFF   (después de compute_tendency, con signo)
//   x25 = longitud del buffer de salida
//   x26 = contador de líneas (en lectura)
// -----------------------------------------------------------------------------
_start:
    // ========================================================================
    // BLOQUE AUTO-CONTENIDO DE LECTURA/PARSING
    // TODO(utils.s): Reemplazar secciones 1-4 por:
    //     bl   utils_open_csv
    //     mov  x0, #TARGET_COL
    //     adr  x1, values_buf
    //     bl   utils_read_int_column
    //     bl   utils_close_csv
    // ========================================================================

    // ---- 1) Abrir lecturas.csv (openat) ----
    mov  x0, #AT_FDCWD                     // x0 = directorio actual
    adr  x1, csv_path                      // x1 = ruta del CSV
    mov  x2, #O_RDONLY                     // x2 = solo lectura
    mov  x3, #0                            // x3 = modo (ignorado en O_RDONLY)
    mov  x8, #SYS_OPENAT                   // x8 = número de syscall
    svc  #0                                // llamada al kernel
    cmp  x0, #0                            // verifico fd >= 0
    b.lt error_exit                        // si falló, salgo con código 1
    mov  x19, x0                           // x19 = fd de entrada

    // ---- 2) Saltar la línea de cabecera del CSV (ID,TEMP,...) ----
    // Lee byte a byte hasta encontrar '\n'
skip_header:
    mov  x0, x19                           // x0 = fd
    adr  x1, line_buf                      // x1 = buffer temporal
    mov  x2, #1                            // x2 = 1 byte
    mov  x8, #SYS_READ                     // syscall read
    svc  #0
    cmp  x0, #0                            // ¿EOF?
    b.le read_done                         // si no hay más datos, terminar
    ldrb w6, [x1]                          // w6 = byte leído
    cmp  w6, #'\n'                         // ¿fin de cabecera?
    b.ne skip_header                       // no, seguir leyendo

    // ---- 3) Leer 30 líneas y parsear columna TARGET_COL ----
    mov  x26, #0                           // x26 = i = 0 (contador de registros)
read_loop:
    cmp  x26, #N_VALUES                    // ¿ya leí 30?
    b.ge read_done                         // sí, salir del loop

    // Leer una línea completa byte a byte hasta '\n'
    mov  x5, #0                            // x5 = índice dentro de line_buf
read_line_loop:
    mov  x0, x19                           // x0 = fd
    adr  x1, line_buf                      // x1 = base de line_buf
    add  x1, x1, x5                        // x1 = line_buf + x5
    mov  x2, #1                            // x2 = 1 byte
    mov  x8, #SYS_READ                     // syscall read
    svc  #0
    cmp  x0, #0                            // ¿EOF?
    b.le read_done                         // sí, terminar
    ldrb w6, [x1]                          // w6 = byte leído
    cmp  w6, #'\n'                         // ¿fin de línea?
    b.eq parse_line                        // sí, parsear esta línea
    add  x5, x5, #1                        // no, avanzar índice
    cmp  x5, #126                          // ¿límite del buffer? (128 - 2 margen)
    b.lt read_line_loop                    // no, seguir leyendo
    b    parse_line                        // buffer lleno, parsear lo que hay

parse_line:
    // Colocar terminador NUL al final de la línea
    adr  x1, line_buf                      // x1 = base de line_buf
    strb wzr, [x1, x5]                     // line_buf[x5] = '\0'

    // Parsear la columna TARGET_COL de la línea
    // TODO(utils.s): Reemplazar por utils_read_int_column
    adr  x0, line_buf                      // x0 = buffer con la línea
    mov  x1, #TARGET_COL                   // x1 = columna objetivo (1 = TEMP)
    bl   parse_csv_column                  // x0 = valor entero parseado

    // Guardar en values_buf[i]
    adr  x9, values_buf                    // x9 = base del arreglo
    lsl  x10, x26, #3                     // x10 = i * 8  (offset en bytes)
    str  x0, [x9, x10]                    // values_buf[i] = x0
    add  x26, x26, #1                     // i++
    b    read_loop                         // siguiente línea

read_done:
    // ---- 4) Cerrar archivo de entrada ----
    mov  x0, x19                           // x0 = fd
    mov  x8, #SYS_CLOSE                    // syscall close
    svc  #0

    // ========================================================================
    // FIN DEL BLOQUE AUTO-CONTENIDO — a partir de aquí es lógica propia
    // ========================================================================

    // ---- 5) Calcular tendencia con la subrutina propia compute_tendency ----
    adr  x0, values_buf                    // x0 = dirección base del arreglo
    bl   compute_tendency                  // Retorna:
                                           //   x20 = INCREMENTS
                                           //   x21 = DECREMENTS
                                           //   x22 = MAX_UP_STREAK
                                           //   x23 = MAX_DOWN_STREAK
                                           //   x24 = ACCUM_DIFF (con signo)

    // ---- 6) Construir archivo de salida en out_buf ----
    // TODO(utils.s): Reemplazar por utils_write_result cuando esté disponible
    adr  x9, out_buf                       // x9 = cursor de salida

    // Línea 1: "MODULE=ADVANCED_TREND\n"
    adr  x0, lbl_module
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // Línea 2: "TOTAL_VALUES=30\n"
    adr  x0, lbl_total
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // Línea 3: "INCREMENTS=<valor>\n"
    adr  x0, lbl_incr
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x20                           // valor = INCREMENTS
    mov  x1, x9
    bl   int_to_ascii
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // Línea 4: "DECREMENTS=<valor>\n"
    adr  x0, lbl_decr
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x21                           // valor = DECREMENTS
    mov  x1, x9
    bl   int_to_ascii
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // Línea 5: "MAX_UP_STREAK=<valor>\n"
    adr  x0, lbl_maxup
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x22                           // valor = MAX_UP_STREAK
    mov  x1, x9
    bl   int_to_ascii
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // Línea 6: "MAX_DOWN_STREAK=<valor>\n"
    adr  x0, lbl_maxdn
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    mov  x0, x23                           // valor = MAX_DOWN_STREAK
    mov  x1, x9
    bl   int_to_ascii
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // Línea 7: "ACCUM_DIFF=<valor>\n"
    //   ACCUM_DIFF puede ser negativo, hay que manejar el signo
    adr  x0, lbl_accum
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    // Verificar si ACCUM_DIFF es negativo
    cmp  x24, #0                           // ¿ACCUM_DIFF >= 0?
    b.ge accum_positive                    // sí, escribir directamente
    // Es negativo: escribir '-' y negar el valor
    adr  x0, minus_sign
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    neg  x0, x24                           // x0 = abs(ACCUM_DIFF)
    mov  x1, x9
    bl   int_to_ascii
    mov  x9, x0
    b    accum_newline
accum_positive:
    mov  x0, x24                           // valor = ACCUM_DIFF (positivo o 0)
    mov  x1, x9
    bl   int_to_ascii
    mov  x9, x0
accum_newline:
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // Línea 8: "TREND=<UP|DOWN|STABLE>\n"
    adr  x0, lbl_trend
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    // Determinar cadena de tendencia basándose en ACCUM_DIFF
    cmp  x24, #0
    b.gt trend_up                          // ACCUM_DIFF > 0 → "UP"
    b.lt trend_down                        // ACCUM_DIFF < 0 → "DOWN"
    // ACCUM_DIFF == 0 → "STABLE"
    adr  x0, str_stable
    b    trend_write
trend_up:
    adr  x0, str_up
    b    trend_write
trend_down:
    adr  x0, str_down
trend_write:
    mov  x1, x9
    bl   copy_str
    mov  x9, x0
    adr  x0, nl
    mov  x1, x9
    bl   copy_str
    mov  x9, x0

    // Calcular longitud total escrita = x9 - out_buf
    adr  x10, out_buf
    sub  x25, x9, x10                     // x25 = longitud del buffer

    // ---- 7) Abrir results/resultado_tendencia.txt para escritura ----
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
    mov  x2, x25                           // x2 = longitud
    mov  x8, #SYS_WRITE                    // syscall write
    svc  #0

    // Cerrar archivo de salida
    mov  x0, x19
    mov  x8, #SYS_CLOSE
    svc  #0

    // ---- 9) Salir con éxito ----
    mov  x0, #0                            // código de salida = 0
    mov  x8, #SYS_EXIT
    svc  #0

error_exit:
    mov  x0, #1                            // código de salida = 1 (error)
    mov  x8, #SYS_EXIT
    svc  #0


// =============================================================================
// compute_tendency — SUBRUTINA PROPIA OBLIGATORIA (Módulo 5)
// =============================================================================
// Calcula las métricas de tendencia acumulada sobre un arreglo de 30 enteros.
//
// Entrada:
//   x0 = dirección base de values_buf (arreglo de 30 enteros de 8 bytes)
//
// Salida (registros callee-saved):
//   x20 = INCREMENTS     — cantidad de diferencias positivas (DIF_i > 0)
//   x21 = DECREMENTS     — cantidad de diferencias negativas (DIF_i < 0)
//   x22 = MAX_UP_STREAK  — máxima racha consecutiva de incrementos
//   x23 = MAX_DOWN_STREAK— máxima racha consecutiva de decrementos
//   x24 = ACCUM_DIFF     — suma acumulada de todas las diferencias (con signo)
//
// Registros internos (scratch):
//   x9  = base del arreglo (copia de x0)
//   x10 = índice i (1..29)
//   x11 = valor anterior (values[i-1])
//   x12 = valor actual   (values[i])
//   x13 = diff = current - previous
//   x14 = curr_up_streak   (racha de subida actual)
//   x15 = curr_down_streak (racha de bajada actual)
//   x16 = temporal para offset de carga
//
// Algoritmo (pseudocódigo):
//   increments = 0; decrements = 0
//   curr_up = 0; curr_down = 0
//   max_up = 0; max_down = 0
//   acc = 0
//   for i = 1; i < 30; i++:
//       previous = values[i-1]
//       current  = values[i]
//       diff = current - previous
//       acc += diff
//       if diff > 0:
//           increments++; curr_up++; curr_down = 0
//           if curr_up > max_up: max_up = curr_up
//       else if diff < 0:
//           decrements++; curr_down++; curr_up = 0
//           if curr_down > max_down: max_down = curr_down
//       else: // diff == 0
//           curr_up = 0; curr_down = 0
//   return (increments, decrements, max_up, max_down, acc)
//
// Nota para GDB:
//   break compute_tendency
//   info registers x20 x21 x22 x23 x24
// =============================================================================
compute_tendency:
    stp  x29, x30, [sp, #-16]!            // prólogo: guardar frame pointer y link reg
    mov  x29, sp

    // Inicializar registros de salida
    mov  x20, #0                           // INCREMENTS = 0
    mov  x21, #0                           // DECREMENTS = 0
    mov  x22, #0                           // MAX_UP_STREAK = 0
    mov  x23, #0                           // MAX_DOWN_STREAK = 0
    mov  x24, #0                           // ACCUM_DIFF = 0

    // Inicializar registros internos
    mov  x9, x0                            // x9 = base del arreglo
    mov  x10, #1                           // x10 = i = 1 (empezamos en el segundo)
    mov  x14, #0                           // curr_up_streak = 0
    mov  x15, #0                           // curr_down_streak = 0

    // Cargar el primer valor (values[0]) como "anterior" para la primera iteración
    ldr  x11, [x9]                         // x11 = values[0]

ct_loop:
    cmp  x10, #N_VALUES                    // ¿i >= 30?
    b.ge ct_done                           // sí, salir del loop

    // Cargar values[i]
    lsl  x16, x10, #3                     // x16 = i * 8  (offset en bytes)
    ldr  x12, [x9, x16]                   // x12 = values[i] (valor actual)

    // Calcular diff = current - previous
    sub  x13, x12, x11                    // x13 = diff = values[i] - values[i-1]

    // Acumular diferencia
    add  x24, x24, x13                    // ACCUM_DIFF += diff

    // Clasificar la diferencia
    cmp  x13, #0                          // ¿diff == 0?
    b.gt ct_positive                      // diff > 0 → incremento
    b.lt ct_negative                      // diff < 0 → decremento
    // diff == 0 → resetear ambas rachas
    mov  x14, #0                           // curr_up = 0
    mov  x15, #0                           // curr_down = 0
    b    ct_next                           // siguiente iteración

ct_positive:
    // diff > 0: es un incremento
    add  x20, x20, #1                     // INCREMENTS++
    add  x14, x14, #1                     // curr_up_streak++
    mov  x15, #0                           // curr_down_streak = 0 (se rompe racha negativa)
    // Actualizar MAX_UP_STREAK si curr_up > max_up
    cmp  x14, x22                         // ¿curr_up > MAX_UP_STREAK?
    b.le ct_next                          // no, seguir
    mov  x22, x14                         // MAX_UP_STREAK = curr_up
    b    ct_next

ct_negative:
    // diff < 0: es un decremento
    add  x21, x21, #1                     // DECREMENTS++
    add  x15, x15, #1                     // curr_down_streak++
    mov  x14, #0                           // curr_up_streak = 0 (se rompe racha positiva)
    // Actualizar MAX_DOWN_STREAK si curr_down > max_down
    cmp  x15, x23                         // ¿curr_down > MAX_DOWN_STREAK?
    b.le ct_next                          // no, seguir
    mov  x23, x15                         // MAX_DOWN_STREAK = curr_down
    b    ct_next

ct_next:
    // Preparar siguiente iteración
    mov  x11, x12                         // previous = current (para la próxima iteración)
    add  x10, x10, #1                     // i++
    b    ct_loop                          // repetir

ct_done:
    // Los resultados ya están en x20..x24 como registros callee-saved
    ldp  x29, x30, [sp], #16              // epílogo: restaurar frame pointer y link reg
    ret


// =============================================================================
// parse_csv_column — extrae el valor entero de la columna N de una línea CSV
// =============================================================================
// TODO(utils.s): Esta subrutina debería moverse a utils.s como parte de
// utils_read_int_column. Cuando utils.s esté funcional, eliminar esta copia
// local y usar .extern utils_read_int_column.
// -----------------------------------------------------------------------------
// Entradas:
//   x0 = puntero al inicio de la línea (terminada en '\n' o '\0')
//   x1 = índice de la columna (0 = ID, 1 = TEMP, 2 = HUM_AIRE, ...)
// Salida:
//   x0 = valor entero de la columna solicitada (0 si EOF/inválido)
//
// Procedimiento:
//   1. Avanzar por campos hasta llegar a la columna objetivo
//      (cada campo termina en ','; el último en '\n' o '\0')
//   2. Acumular dígitos decimales hasta encontrar delimitador
// =============================================================================
parse_csv_column:
    stp  x29, x30, [sp, #-16]!            // prólogo: guardar fp/lr
    mov  x29, sp
    mov  x2, x0                            // x2 = cursor de lectura
    mov  x3, x1                            // x3 = columna objetivo
    mov  x4, #0                            // x4 = columna actual

parse_skip_outer:
    cmp  x4, x3                            // ¿llegamos a la columna objetivo?
    b.ge parse_read_int                    // sí, empezar a leer el entero
parse_skip_field:                          // sino, saltar el campo actual
    ldrb w5, [x2]                          // cargar byte actual
    cbz  w5, parse_eof                     // si es NUL, fin de string
    cmp  w5, #'\n'                         // si es newline, fin de línea
    b.eq parse_eof
    cmp  w5, #','                          // si es coma, fin de campo
    b.ne parse_skip_next                   // si no, seguir avanzando
    add  x2, x2, #1                        // avanzar más allá de la coma
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
    cmp  w5, #'0'                          // ¿es dígito? (< '0')
    b.lt parse_done
    cmp  w5, #'9'                          // ¿es dígito? (> '9')
    b.gt parse_done
    mul  x0, x0, x6                        // acc = acc * 10
    sub  w5, w5, #'0'                      // convertir ASCII a número
    add  x0, x0, x5                        // acc = acc + dígito
    add  x2, x2, #1                        // siguiente byte
    b    parse_digit

parse_eof:
    mov  x0, #0                            // EOF → 0
parse_done:
    ldp  x29, x30, [sp], #16               // epílogo
    ret


// =============================================================================
// int_to_ascii — convierte un entero no-negativo a su representación ASCII
// =============================================================================
// TODO(utils.s): Esta subrutina debería moverse a utils.s como utils_print_i64.
// Cuando utils.s esté funcional, eliminar esta copia local.
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
    stp  x29, x30, [sp, #-32]!            // prólogo
    mov  x29, sp
    stp  x19, x20, [sp, #16]               // guardar x19/x20
    mov  x19, x0                           // x19 = valor
    mov  x20, x1                           // x20 = buffer destino

    cbnz x19, itoa_non_zero                // si valor != 0, continuar
    // Caso especial: valor = 0
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
    add  x6, x6, #'0'                      // x6 = carácter ASCII del dígito
    strb w6, [x2, x3]                      // guardar en buffer temporal
    add  x3, x3, #1                        // contador++
    mov  x19, x5                           // valor = cociente
    cbnz x19, itoa_digit                   // repetir mientras cociente != 0

    // Copiar dígitos al destino en orden inverso (MSB primero)
    mov  x7, #0                            // x7 = índice de copia
itoa_copy:
    sub  x3, x3, #1                        // x3-- (empezar desde el último dígito)
    ldrb w6, [x2, x3]                      // cargar dígito (del final hacia el inicio)
    strb w6, [x20, x7]                     // escribir en buffer destino
    add  x7, x7, #1                        // avanzar destino
    cbnz x3, itoa_copy                     // repetir hasta copiar todos

    add  sp, sp, #32                       // liberar buffer temporal
    add  x0, x20, x7                       // x0 = destino + bytes escritos
itoa_done:
    ldp  x19, x20, [sp, #16]               // restaurar x19/x20
    ldp  x29, x30, [sp], #32               // epílogo
    ret


// =============================================================================
// copy_str — copia un string ASCIIZ (terminado en NUL) a un buffer
// =============================================================================
// TODO(utils.s): Esta subrutina es una utilidad genérica de strings que
// podría incluirse en utils.s. Cuando esté disponible, eliminar copia local.
// -----------------------------------------------------------------------------
// Entradas:
//   x0 = puntero al string origen (NUL-terminated)
//   x1 = puntero al buffer destino
// Salida:
//   x0 = puntero al siguiente byte libre (donde estaba el NUL)
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
    mov  x0, x1                            // retornar destino (siguiente byte libre)
    ret
