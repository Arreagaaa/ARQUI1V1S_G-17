// anomalias.s — Integrante 3 — Grupo 17
.equ N_VALUES, 30

.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

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

.section .bss
.align 3
values_buf:  .skip 8 * N_VALUES
out_buf:     .skip 512

.section .text
.global _start

_start:
    bl   utils_open_csv
    mov  x19, x0            // x19 = File Descriptor

    mov  x0, x19
    mov  x1, #1             // x1 = Columna 1
    adr  x2, values_buf
    mov  x3, #1             // fila inicio
    mov  x4, #N_VALUES      // fila fin
    bl   utils_read_int_column
    
    cmp  x0, #N_VALUES      // Validar lectura nueva utils
    beq  anom_read_ok
    b    error_exit
anom_read_ok:

    mov  x0, x19
    bl   utils_close_csv

    // CALCULO MEDIA
    mov x10, #0             // x10 = contador i
    mov x11, #0             // x11 = suma total
    adr x12, values_buf
ciclo_media:
    cmp x10, #30
    bge fin_media
    b anom_media_body
anom_media_body:
    ldr x14, [x12, x10, lsl #3]
    add x11, x11, x14       // Acumular
    add x10, x10, #1
    b ciclo_media
fin_media:
    mov x15, #30
    udiv x21, x11, x15      // x21 = Media

    // CALCULO DESVIACIÓN
    mov x10, #0
    mov x11, #0
    adr x12, values_buf
ciclo_varianza:
    cmp x10, #30
    bge fin_varianza
    b anom_var_body
anom_var_body:
    ldr x14, [x12, x10, lsl #3]
    sub x15, x14, x21       // (Xi - media)
    mul x16, x15, x15       // (Xi - media)^2
    add x11, x11, x16       // Acumular sum_sq
    add x10, x10, #1
    b ciclo_varianza
fin_varianza:
    mov x15, #30
    udiv x17, x11, x15      // x17 = Varianza
    mov x22, #0             // x22 = StdDev
ciclo_raiz:
    mul x18, x22, x22
    cmp x18, x17
    ble anom_raiz_cont
    b fin_raiz
anom_raiz_cont:
    add x22, x22, #1
    b ciclo_raiz
fin_raiz:
    sub x22, x22, #1
    cmp x22, #0
    beq anom_std_failsafe
    b desviacion_lista
anom_std_failsafe:
    mov x22, #1             // Failsafe div por cero
desviacion_lista:

    // Z-SCORE Y ANOMALÍAS
    mov x23, #0             // x23 = contador anomalías
    mov x10, #0
    adr x12, values_buf
ciclo_zscore:
    cmp x10, #30
    bge fin_zscore
    b anom_zscore_cont
anom_zscore_cont:
    ldr x14, [x12, x10, lsl #3]
    sub x15, x14, x21       // X_i - media
    sdiv x16, x15, x22      // Z = diff / std
    cmp x16, #0             // Valor absoluto
    bge check_anomalia
    neg x16, x16
check_anomalia:
    cmp x16, #2             // Umbral |Z| >= 2
    bge anom_detected
    b siguiente_z
anom_detected:
    add x23, x23, #1        // Anomalía detectada
siguiente_z:
    add x10, x10, #1
    b ciclo_zscore
fin_zscore:

    // RIESGO
    cmp x23, #0
    bne anom_check_risk
    b riesgo_normal
anom_check_risk:
    cmp x23, #3
    ble riesgo_medio
    b anom_risk_high
anom_risk_high:
    adr x24, str_high
    b fin_riesgo
riesgo_normal: adr x24, str_normal
    b fin_riesgo
riesgo_medio: adr x24, str_medium
fin_riesgo:

    // CONSTRUIR SALIDA
    adr  x26, out_buf
    adr  x0, lbl_module
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

    adr  x0, lbl_total
    mov  x1, x26
    bl   copy_str
    mov  x26, x0

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

    adr  x10, out_buf
    sub  x2, x26, x10
    adr  x0, out_path
    adr  x1, out_buf
    bl   utils_write_result

    mov  x0, #0
    bl   utils_exit
error_exit:
    mov  x0, #1
    bl   utils_exit

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