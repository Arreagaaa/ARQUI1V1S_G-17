// =============================================================================
// anomalias.s — Módulo 3: Detección estadística de anomalías
// Integrante 3 — Grupo 17 — ACYE1 Invernadero Inteligente IoT
// =============================================================================
// Lee la columna TEMP del archivo lecturas.csv (30 datos reales),
// calcula media, desviación estándar, z-score y total de anomalías,
// y escribe el resultado en results/resultado_anomalias.txt.
// =============================================================================

// ---------------------------------------------------------------------------
// Constantes del módulo
// ---------------------------------------------------------------------------
.equ N_VALUES,        30

// ---------------------------------------------------------------------------
// Símbolos externos de utils.s
// ---------------------------------------------------------------------------
.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

// =============================================================================
// .rodata — strings de solo lectura
// =============================================================================
.section .rodata
.align 3

out_path:   .asciz "results/resultado_anomalias.txt"

lbl_module: .asciz "MODULE=ANOMALY_DETECTION\n"
lbl_total:  .asciz "TOTAL_VALUES=30\n"
lbl_mean:   .asciz "MEAN="
lbl_std:    .asciz "STD_DEV="
lbl_anom:   .asciz "ANOMALIES="
lbl_risk:   .asciz "SYSTEM_RISK="
nl:         .asciz "\n"

str_normal: .asciz "NORMAL"
str_medium: .asciz "MEDIUM"
str_high:   .asciz "HIGH"

// =============================================================================
// .bss — buffers en memoria no inicializada
// =============================================================================
.section .bss
.align 3

values_buf:  .skip 8 * N_VALUES       // arreglo de 30 enteros i64
out_buf:     .skip 512                // buffer de salida completo

// =============================================================================
// .text — código
// =============================================================================
.section .text
.global _start

_start:
    // ---- 1) Abrir lecturas.csv ----
    bl   utils_open_csv
    mov  x19, x0

    // ---- 2) Leer columna 1 (TEMP) en values_buf ----
    mov  x0, x19
    mov  x1, #1
    adr  x2, values_buf
    bl   utils_read_int_column
    cmp  x0, #N_VALUES
    b.ne error_exit

    // ---- 3) Cerrar el CSV ----
    mov  x0, x19
    bl   utils_close_csv

    // =========================================================================
    // AQUI EMPIEZA CALCULOS DE MEDIA, DESVIACIÓN, Z-SCORE, ANOMALÍAS Y RIESGO

    //Direcciones de los resultados finales:
    //   x21 = Valor de la Media
    //   x22 = Valor de la Desviación Estándar
    //   x23 = Total de Anomalías (0, 1, 2, 4...)
    //   x24 = Dirección de memoria del texto de riesgo (str_normal, str_medium o str_high)
    // =========================================================================

    //
    // =========================================================================
    // BLOQUE 1: Calcular la Media Aritmética
    // =========================================================================

    mov x10, #0                // x10 contador i = 0 para el ciclo
    mov x11, #0                // x11  acumulador (la suma total)
    adr x12, values_buf        // x12 tiene la dirección base donde están los 30 números

ciclo_media:
    cmp x10, #30               // ¿i >= 30?
    b.ge fin_media             // Si i >= 30 salta al final del ciclo

    lsl x13, x10, #3           // x13 = i * 8 (calcula el offset en bytes)
    ldr x14, [x12, x13]        // x14 = Carga el número desde la memoria (values_buf + offset)

    add x11, x11, x14          // sumaTotal += numero_leido
    add x10, x10, #1           // i++
    b ciclo_media              // Regresa al inicio del ciclo

fin_media:
    mov x15, #30               // x15 = 30 (nuestro total de datos)
    udiv x21, x11, x15         // x21 = Media Aritmética (Suma Total / 30)


    // =========================================================================
    // BLOQUE 2: Calcular la Desviación Estándar
    // =========================================================================

    // Calcular la Varianza
    mov x10, #0                // x10 = i = 0
    mov x11, #0                // x11 = suma de diferencias al cuadrado
    adr x12, values_buf        // x12 = dirección base del arreglo

ciclo_varianza:
    cmp x10, #30               // ¿i >= 30?
    b.ge fin_varianza          // Si i >= 30, salir del ciclo

    lsl x13, x10, #3           // Offset: i * 8 bytes
    ldr x14, [x12, x13]        // Cargar X_i

    // Restar la media: (X_i - media)
    sub x15, x14, x21          // x15 = (X_i - media)

    // Elevar al cuadrado: (X_i - media)^2
    mul x16, x15, x15          // x16 = x15 * x15

    // Acumular
    add x11, x11, x16          // sum_sq += cuadrado
    add x10, x10, #1           // i++
    b ciclo_varianza

fin_varianza:
    mov x15, #30               // Total de datos
    udiv x17, x11, x15         // x17 = Varianza (Suma Total / 30)

    //  Calcular la Raíz Cuadrada (Búsqueda Lineal)
    // Buscamos un número r (x22) tal que r*r <= Varianza
    mov x22, #0                // Empezamos probando con la raíz = 0

ciclo_raiz:
    mul x18, x22, x22          // r * r
    cmp x18, x17               // Comparamos r^2 con la Varianza
    b.gt fin_raiz              // Si r^2 > Varianza, nos pasamos, fin del ciclo
    add x22, x22, #1           // r++
    b ciclo_raiz               // Volver a probar

fin_raiz:
    sub x22, x22, #1           // Como el ciclo se pasó por 1, le restamos 1 para tener el valor exacto

    // Si todos los datos son iguales, la desviación es 0
    // Pero si es 0, el Z-Score fallará por dar indefinido (división por cero)
    // Lo forzamos a 1 para evitar que el programa colapse.
    cmp x22, #0                // ¿La desviación dio 0?
    b.ne desviacion_lista      // Si no es cero, todo bien
    mov x22, #1                // Si es cero la forzamos a 1 por seguridad

desviacion_lista:
    //x22 ya tiene Desviación Estándar.


    // =========================================================================
    // BLOQUE 3: Calcular Z-Score y Contar Anomalías
    // =========================================================================

    mov x23, #0                // x23 = Contador de anomalías (Inicia en 0)
    mov x10, #0                // x10 = i = 0
    adr x12, values_buf        // x12 = dirección base del arreglo

ciclo_zscore:
    cmp x10, #30               // ¿Ya recorrimos los 30 datos?
    b.ge fin_zscore            // Si i >= 30, salir del ciclo

    lsl x13, x10, #3           // Offset: i * 8 bytes
    ldr x14, [x12, x13]        // Cargar X_i

    // Z = (X_i - media) / std_dev
    sub x15, x14, x21          // x15 = X_i - media (¡Ojo! Puede dar negativo)

    // Aquí usamos SDIV (División con Signo) porque el Z-Score puede ser bajo cero
    sdiv x16, x15, x22         // x16 = Z-Score

    // Obtener el valor absoluto de Z (|Z|)
    cmp x16, #0                // ¿El Z-Score es negativo?
    b.ge check_anomalia        // Si es >= 0 (positivo), sáltate la conversión
    neg x16, x16               // Si es < 0 (negativo), invierte su signo para volverlo positivo

check_anomalia:
    // Regla: |Z| >= 2 = ANOMALIA
    cmp x16, #2                // Compara el |Z| con el límite de 2
    b.lt siguiente_z           // El guardia actúa: si es menor a 2, no es anomalía, ¡sáltate el contador!

    add x23, x23, #1           // Si no saltó, es una anomalía: sumamos 1 a x23

siguiente_z:
    add x10, x10, #1           // i++
    b ciclo_zscore             // Repetir el ciclo

fin_zscore:
    // Al salir del ciclo x23 ya tiene el total matemático de anomalías.

    // =========================================================================
    // BLOQUE 4: Clasificación del Riesgo (SYSTEM_RISK)
    // =========================================================================

    cmp x23, #0
    b.eq riesgo_normal         // Si anomalías == 0 -> Ve a NORMAL

    cmp x23, #3
    b.le riesgo_medio          // Si anomalías es <= 3 -> Ve a MEDIUM

    adr x24, str_high          // El riesgo es HIGH
    b fin_riesgo

riesgo_normal:
    adr x24, str_normal
    b fin_riesgo

riesgo_medio:
    adr x24, str_medium

fin_riesgo:

    // =========================================================================
    // CONSTRUIR SALIDA
    // =========================================================================

    adr  x26, out_buf                 // x26 = cursor de escritura

    // L1: "MODULE=ANOMALY_DETECTION\n"
    adr  x0, lbl_module
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // L2: "TOTAL_VALUES=30\n"
    adr  x0, lbl_total
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // L3: "MEAN=<media>\n"
    adr  x0, lbl_mean
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    mov  x0, x21
    mov  x1, x26
    bl   utils_i64_to_str
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // L4: "STD_DEV=<std_dev>\n"
    adr  x0, lbl_std
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    mov  x0, x22
    mov  x1, x26
    bl   utils_i64_to_str
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // L5: "ANOMALIES=<anomalias>\n"
    adr  x0, lbl_anom
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    mov  x0, x23
    mov  x1, x26
    bl   utils_i64_to_str
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // L6: "SYSTEM_RISK=<riesgo>\n"
    adr  x0, lbl_risk
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    mov  x0, x24
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // ---- Escribir archivo de resultados ----
    adr  x10, out_buf
    sub  x2, x26, x10
    adr  x0, out_path
    adr  x1, out_buf
    bl   utils_write_result

    // ---- Salir con éxito ----
    mov  x0, #0
    bl   utils_exit

error_exit:
    mov  x0, #1
    bl   utils_exit

// =============================================================================
// copy_str — copia un string ASCIIZ
// =============================================================================
copy_str:
    ldrb w2, [x0]
    cbz  w2, copy_str_done
    strb w2, [x1]
    add  x0, x0, #1
    add  x1, x1, #1
    b    copy_str
copy_str_done:
    mov  x0, x1
    ret