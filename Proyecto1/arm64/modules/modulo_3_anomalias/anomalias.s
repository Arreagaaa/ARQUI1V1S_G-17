// =============================================================================
// anomalias.s — Módulo 3: Detección estadística de anomalías
// Integrante 3 — Grupo 17 — ACYE1 Invernadero Inteligente IoT
// =============================================================================
// Lee la columna TEMP del archivo lecturas.csv (30 datos reales),
// calcula media, desviación estándar, z-score y total de anomalías,
// y escribe el resultado en results/resultado_anomalias.txt.
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
out_path:   .asciz "results/resultado_anomalias.txt"

// Etiquetas de salida (formato EXACTO del enunciado)
lbl_module: .asciz "MODULE=ANOMALY_DETECTION\n"
lbl_total:  .asciz "TOTAL_VALUES=30\n"
lbl_mean:   .asciz "MEAN="
lbl_std:    .asciz "STD_DEV="
lbl_anom:   .asciz "ANOMALIES="
lbl_risk:   .asciz "SYSTEM_RISK="
nl:         .asciz "\n"

// Opciones de riesgo
str_normal: .asciz "NORMAL"
str_medium: .asciz "MEDIUM"
str_high:   .asciz "HIGH"

// =============================================================================
// .bss — buffers en memoria no inicializada
// =============================================================================
.section .bss
.align 3

line_buf:    .skip 64                 // buffer para 1 línea del CSV
values_buf:  .skip 8 * N_VALUES       // arreglo de 30 enteros i64
out_buf:     .skip 512                // buffer de salida completo

// =============================================================================
// .text — código
// =============================================================================
.section .text
.global _start

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
    b    read_line_loop               // línea muy larga (>63 bytes), seguir leyendo pero truncar a 63

parse_line:
    mov  w6, #0
    adr  x7, line_buf
    add  x7, x7, x5
    strb w6, [x7]

    adr  x0, line_buf
    mov  x1, #1                       // 1 = Columna TEMP
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

    // Leer el valor values_buf[i]
    // Cada número i64 mide 8 bytes Si i=1 el offset es 8. Si i=2, es 16
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
    // Si da negativo el cuadrado lo arregla
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
    // Aquí decidimos a dónde debe apuntar x24 (str_normal, str_medium, o str_high)

    cmp x23, #0
    b.eq riesgo_normal         // Si anomalías == 0 -> Ve a NORMAL

    cmp x23, #3
    b.le riesgo_medio          // Si anomalías es <= 3 -> Ve a MEDIUM

    // Si sobrevivió a las dos pruebas anteriores, por descarte son 4 o más
    adr x24, str_high          // El riesgo es HIGH
    b fin_riesgo               // GOTO ciego para salir del bloque

riesgo_normal:
    adr x24, str_normal        // El riesgo es NORMAL
    b fin_riesgo               // GOTO ciego

riesgo_medio:
    adr x24, str_medium        // El riesgo es MEDIUM

fin_riesgo:
    // Fin calculo x24 ya sabe qué palabra imprimir.

    // =========================================================================
    // FIN DE LOS CALCULOS CONSTRUIR SALIDA
    // =========================================================================
    //
    //Empezar a construir el buffer para escribir el archivo txt


    // ---- 6) Construir buffer de salida en out_buf ----
    adr  x26, out_buf                 // x26 = cursor de escritura

    // Línea 1: "MODULE=ANOMALY_DETECTION\n"
    adr  x0, lbl_module
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // Línea 2: "TOTAL_VALUES=30\n"
    adr  x0, lbl_total
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // Línea 3: "MEAN=<media>\n"
    adr  x0, lbl_mean
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    mov  x0, x21                      // Aquí usamos la media
    mov  x1, x26
    bl   int_to_ascii
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // Línea 4: "STD_DEV=<std_dev>\n"
    adr  x0, lbl_std
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    mov  x0, x22                      // Aquí usamos la desviación
    mov  x1, x26
    bl   int_to_ascii
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // Línea 5: "ANOMALIES=<anomalias>\n"
    adr  x0, lbl_anom
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    mov  x0, x23                      // Aquí usamos el total de anomalías
    mov  x1, x26
    bl   int_to_ascii
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // Línea 6: "SYSTEM_RISK=<riesgo>\n" 
    adr  x0, lbl_risk
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    mov  x0, x24                      // Aquí usamos el string de riesgo
    mov  x1, x26
    bl   copy_str
    mov  x26, x0
    adr  x0, nl
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    // ---- 7) Calcular longitud total del buffer ----
    adr  x10, out_buf
    sub  x27, x26, x10                // x27 = bytes a escribir

    // ---- 8) Abrir results/resultado_anomalias.txt (escritura) ----
    mov  x0, #AT_FDCWD
    adr  x1, out_path
    mov  x2, #577                     // O_WRONLY | O_CREAT | O_TRUNC (en decimal es aprox 577, respetamos el de tu compañero)
    mov  x3, #0644                    // permisos rw-r--r--
    mov  x8, #SYS_OPENAT
    svc  #0
    cmp  x0, #0
    b.lt error_exit
    mov  x19, x0                      // x19 = fd de salida

    // ---- 9) Escribir buffer completo y cerrar ----
    mov  x0, x19
    adr  x1, out_buf
    mov  x2, x27
    mov  x8, #SYS_WRITE
    svc  #0

    mov  x0, x19
    mov  x8, #SYS_CLOSE
    svc  #0

    // ---- 10) exit(0) ----
    mov  x0, #0
    mov  x8, #SYS_EXIT
    svc  #0

error_exit:
    mov  x0, #1                       // código de error = 1
    mov  x8, #SYS_EXIT
    svc  #0


// =============================================================================
// SUBRUTINAS DE UTILIDAD (NO TOCAR)
// =============================================================================

// parse_csv_column — extrae el valor entero de la columna N
parse_csv_column:
    stp  x29, x30, [sp, #-16]!        
    mov  x29, sp
    mov  x2, x0                       
    mov  x3, x1                       
    mov  x4, #0                       
parse_skip_outer:
    cmp  x4, x3
    b.ge parse_read_int               
parse_skip_field:
    ldrb w5, [x2]
    cbz  w5, parse_eof                
    cmp  w5, #'\n'
    b.eq parse_eof                    
    cmp  w5, #','
    b.ne parse_skip_next              
    add  x2, x2, #1                   
    add  x4, x4, #1                   
    b    parse_skip_outer
parse_skip_next:
    add  x2, x2, #1
    b    parse_skip_field
parse_read_int:
    mov  x0, #0                       
    mov  x6, #10                      
parse_digit:
    ldrb w5, [x2]
    cmp  w5, #'0'
    b.lt parse_done                   
    cmp  w5, #'9'
    b.gt parse_done                   
    mul  x0, x0, x6                   
    sub  w5, w5, #'0'                 
    add  x0, x0, x5                   
    add  x2, x2, #1
    b    parse_digit
parse_eof:
    mov  x0, #0
parse_done:
    ldp  x29, x30, [sp], #16          
    ret

// int_to_ascii — convierte entero a texto
int_to_ascii:
    stp  x29, x30, [sp, #-32]!        
    mov  x29, sp
    stp  x19, x20, [sp, #16]          
    mov  x19, x0                      
    mov  x20, x1                      
    cbnz x19, itoa_non_zero
    mov  w0, #'0'                     
    strb w0, [x20]
    add  x0, x20, #1
    b    itoa_done
itoa_non_zero:
    sub  sp, sp, #32                  
    mov  x2, sp                       
    mov  x3, #0                       
    mov  x4, #10                      
itoa_digit:
    udiv x5, x19, x4                  
    msub x6, x5, x4, x19              
    add  x6, x6, #'0'                 
    strb w6, [x2, x3]                 
    add  x3, x3, #1
    mov  x19, x5                      
    cbnz x19, itoa_digit              
    mov  x7, #0                       
itoa_copy:
    sub  x3, x3, #1
    ldrb w6, [x2, x3]
    strb w6, [x20, x7]
    add  x7, x7, #1
    cbnz x3, itoa_copy
    add  sp, sp, #32                  
    add  x0, x20, x7                  
itoa_done:
    ldp  x19, x20, [sp, #16]          
    ldp  x29, x30, [sp], #32          
    ret

// copy_str — copia un string ASCIIZ
copy_str:
copy_str_loop:
    ldrb w2, [x0]                     
    cbz  w2, copy_str_done            
    strb w2, [x1]                     
    add  x0, x0, #1                   
    add  x1, x1, #1                   
    b    copy_str_loop
copy_str_done:
    mov  x0, x1                       
    ret