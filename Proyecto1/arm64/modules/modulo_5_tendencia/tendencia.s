// =============================================================================
// tendencia.s — Módulo 5: Tendencia acumulada avanzada
// Integrante 5 — Grupo 17 — ACYE1 Invernadero Inteligente IoT
// =============================================================================
// Lee la columna TEMP del archivo lecturas.csv (30 datos reales),
// calcula métricas de tendencia acumulada (incrementos, decrementos,
// rachas, diferencia acumulada y dirección de tendencia) y escribe
// el resultado en results/resultado_tendencia.txt.
//
// Usa las funciones exportadas por utils.s:
//   utils_open_csv          → abre lecturas.csv
//   utils_read_int_column   → lee col N → enteros en buffer
//   utils_close_csv         → cierra fd
//   utils_write_result      → crea y escribe archivo de salida
//   utils_i64_to_str        → convierte entero → ASCII
//   utils_exit              → exit(code)
//
// Subrutina propia del módulo:
//   compute_tendency        → calcula métricas de tendencia
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
// =============================================================================

// -----------------------------------------------------------------------------
// Imports de utils.s
// -----------------------------------------------------------------------------
.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

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

// Ruta relativa al CWD = arm64/  (donde corre `make run5`)
out_path:      .asciz "results/resultado_tendencia.txt"

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
//   1. Abrir  lecturas.csv             → x19 = fd
//   2. Leer   30 valores de col TEMP   → values_buf[30]
//   3. Cerrar archivo de entrada
//   4. Llamar compute_tendency         → x20..x24 = resultados
//   5. Construir archivo de salida     → out_buf
//   6. Escribir resultado con utils_write_result
//   7. exit(0)
//
// Registros de larga vida (callee-saved):
//   x19 = fd (entrada)
//   x20 = INCREMENTS   (después de compute_tendency)
//   x21 = DECREMENTS   (después de compute_tendency)
//   x22 = MAX_UP_STREAK (después de compute_tendency)
//   x23 = MAX_DOWN_STREAK (después de compute_tendency)
//   x24 = ACCUM_DIFF   (después de compute_tendency, con signo)
//   x25 = longitud del buffer de salida
// -----------------------------------------------------------------------------
_start:
    // ========================================================================
    // 1) Abrir lecturas.csv usando utils_open_csv
    // ========================================================================
    bl   utils_open_csv                    // x0 = fd (sale con 1 si falla)
    mov  x19, x0                           // x19 = fd de entrada

    // ========================================================================
    // 2) Leer 30 valores enteros de la columna TEMP
    // ========================================================================
    mov  x0, x19                           // x0 = fd
    mov  x1, #TARGET_COL                   // x1 = columna 1 (TEMP)
    adr  x2, values_buf                    // x2 = buffer destino
    bl   utils_read_int_column             // x0 = cantidad de valores leídos

    // Verificar que se leyeron al menos N_VALUES
    cmp  x0, #N_VALUES
    b.lt error_exit                        // si menos de 30, error

    // ========================================================================
    // 3) Cerrar archivo de entrada
    // ========================================================================
    mov  x0, x19                           // x0 = fd
    bl   utils_close_csv

    // ========================================================================
    // 4) Calcular tendencia con la subrutina propia compute_tendency
    // ========================================================================
    adr  x0, values_buf                    // x0 = dirección base del arreglo
    bl   compute_tendency                  // Retorna:
                                           //   x20 = INCREMENTS
                                           //   x21 = DECREMENTS
                                           //   x22 = MAX_UP_STREAK
                                           //   x23 = MAX_DOWN_STREAK
                                           //   x24 = ACCUM_DIFF (con signo)

    // ========================================================================
    // 5) Construir archivo de salida en out_buf
    // ========================================================================
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
    bl   utils_i64_to_str
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
    bl   utils_i64_to_str
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
    bl   utils_i64_to_str
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
    bl   utils_i64_to_str
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
    bl   utils_i64_to_str
    mov  x9, x0
    b    accum_newline
accum_positive:
    mov  x0, x24                           // valor = ACCUM_DIFF (positivo o 0)
    mov  x1, x9
    bl   utils_i64_to_str
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

    // ========================================================================
    // 6) Escribir resultado usando utils_write_result
    // ========================================================================
    adr  x0, out_path                      // x0 = ruta del archivo
    adr  x1, out_buf                       // x1 = buffer con datos
    mov  x2, x25                           // x2 = longitud
    bl   utils_write_result

    // ========================================================================
    // 7) Salir con éxito
    // ========================================================================
    mov  x0, #0                            // código de salida = 0
    bl   utils_exit

error_exit:
    mov  x0, #1                            // código de salida = 1 (error)
    bl   utils_exit


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
// copy_str — copia un string ASCIIZ (terminado en NUL) a un buffer
// =============================================================================
// Subrutina local del módulo (utils.s no exporta copy_str).
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
