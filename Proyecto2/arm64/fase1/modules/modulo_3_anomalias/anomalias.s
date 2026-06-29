.global _start

.extern utils_parse_i64
.extern utils_validate_range
.extern utils_validate_column
.extern utils_read_int_column
.extern utils_i64_to_str
.extern utils_write_result
.extern utils_exit

.equ MAX_VALUES, 256

.data
out_path:   .asciz "results/resultado_anomalias.txt"
lbl_module: .asciz "MODULE=ANOMALY_DETECTION\n"
lbl_total:  .asciz "TOTAL_VALUES="
lbl_mean:   .asciz "MEAN="
lbl_std:    .asciz "STD_DEV="
lbl_anom:   .asciz "ANOMALIES="
lbl_risk:   .asciz "SYSTEM_RISK="
nl:         .asciz "\n"
str_normal: .asciz "NORMAL"
str_medium: .asciz "MEDIUM"
str_high:   .asciz "HIGH"
lbl_status: .asciz "STATUS=OK\n"

msg_err_argc: .ascii "STATUS=ERROR\nERROR=INVALID_ARGS\nDETAIL=EXPECTED_PATH_START_END_COL\n"
len_err_argc = . - msg_err_argc
msg_err_rng: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=START_END_INVALID\n"
len_err_rng = . - msg_err_rng
msg_err_col: .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_MUST_BE_1_TO_6\n"
len_err_col = . - msg_err_col
msg_err_opn: .ascii "STATUS=ERROR\nERROR=FILE_NOT_FOUND\nDETAIL=COULD_NOT_OPEN_FILE\n"
len_err_opn = . - msg_err_opn
msg_err_read: .ascii "STATUS=ERROR\nERROR=READ_FAILED\nDETAIL=NO_VALUES_READ\n"
len_err_read = . - msg_err_read

.bss
values_buf:  .skip 8 * MAX_VALUES
out_buf:     .skip 512

.text
_start:
    ldr x0, [sp]
    cmp x0, #5
    bge args_ok
    b error_argc
args_ok:
    ldr x19, [sp, #16]
    ldr x0, [sp, #24]
    bl utils_parse_i64
    mov x20, x0
    ldr x0, [sp, #32]
    bl utils_parse_i64
    mov x21, x0
    ldr x0, [sp, #40]
    bl utils_parse_i64
    mov x22, x0

    mov x0, x20
    mov x1, x21
    bl utils_validate_range
    cbnz x0, error_range

    mov x0, x22
    bl utils_validate_column
    cbnz x0, error_column

    mov x0, #-100
    mov x1, x19
    mov x2, #0
    mov x3, #0
    mov x8, #56
    svc #0
    cmp x0, #0
    bge open_ok
    b error_open
open_ok:
    mov x23, x0
    mov x0, x23
    mov x1, x22
    ldr x2, =values_buf
    mov x3, x20
    mov x4, x21
    bl utils_read_int_column
    mov x24, x0
    cmp x24, #1
    bge save_count
    b error_read
save_count:
    mov x19, x24               // preserve count in x19
    mov x0, x23
    mov x8, #57
    svc #0

    // CALCULAR MEDIA
    mov x10, #0
    mov x11, #0
    ldr x12, =values_buf
ciclo_media:
    cmp x10, x19
    bge fin_media
    ldr x14, [x12, x10, lsl #3]
    add x11, x11, x14
    add x10, x10, #1
    b ciclo_media
fin_media:
    mov x15, x19
    udiv x21, x11, x15          // x21 = media

    // CALCULAR VARIANZA
    mov x10, #0
    mov x11, #0
    ldr x12, =values_buf
ciclo_varianza:
    cmp x10, x19
    bge fin_varianza
    ldr x14, [x12, x10, lsl #3]
    sub x15, x14, x21
    mul x16, x15, x15
    add x11, x11, x16
    add x10, x10, #1
    b ciclo_varianza
fin_varianza:
    mov x15, x19
    udiv x17, x11, x15          // x17 = varianza
    mov x22, #0                 // x22 = std_dev
ciclo_raiz:
    mul x18, x22, x22
    cmp x18, x17
    ble cont_raiz
    b fin_raiz
cont_raiz:
    add x22, x22, #1
    b ciclo_raiz
fin_raiz:
    sub x22, x22, #1
    cmp x22, #0
    beq std_failsafe
    b std_ready
std_failsafe:
    mov x22, #1
std_ready:

    // Z-SCORE Y ANOMALIAS
    mov x23, #0                 // x23 = contador anomalias
    mov x10, #0
    ldr x12, =values_buf
ciclo_zscore:
    cmp x10, x19
    bge fin_zscore
    ldr x14, [x12, x10, lsl #3]
    sub x15, x14, x21
    sdiv x16, x15, x22
    cmp x16, #0
    bge check_anomalia
    neg x16, x16
check_anomalia:
    cmp x16, #2
    bge anom_detected
    b siguiente_z
anom_detected:
    add x23, x23, #1
siguiente_z:
    add x10, x10, #1
    b ciclo_zscore
fin_zscore:

    // RIESGO
    cmp x23, #0
    bne check_risk
    b riesgo_normal
check_risk:
    cmp x23, #3
    ble riesgo_medio
    b riesgo_alto
riesgo_alto:
    ldr x24, =str_high
    b fin_riesgo
riesgo_normal:
    ldr x24, =str_normal
    b fin_riesgo
riesgo_medio:
    ldr x24, =str_medium
fin_riesgo:

    // CONSTRUIR SALIDA
    ldr x26, =out_buf
    ldr x0, =lbl_module
    mov x1, x26
    bl copy_str
    mov x26, x0

    ldr x0, =lbl_total
    mov x1, x26
    bl copy_str
    mov x26, x0
    mov x0, x19
    mov x1, x26
    bl utils_i64_to_str
    mov x26, x0
    ldr x0, =nl
    mov x1, x26
    bl copy_str
    mov x26, x0

    ldr x0, =lbl_mean
    mov x1, x26
    bl copy_str
    mov x26, x0
    mov x0, x21
    mov x1, x26
    bl utils_i64_to_str
    mov x26, x0
    ldr x0, =nl
    mov x1, x26
    bl copy_str
    mov x26, x0

    ldr x0, =lbl_std
    mov x1, x26
    bl copy_str
    mov x26, x0
    mov x0, x22
    mov x1, x26
    bl utils_i64_to_str
    mov x26, x0
    ldr x0, =nl
    mov x1, x26
    bl copy_str
    mov x26, x0

    ldr x0, =lbl_anom
    mov x1, x26
    bl copy_str
    mov x26, x0
    mov x0, x23
    mov x1, x26
    bl utils_i64_to_str
    mov x26, x0
    ldr x0, =nl
    mov x1, x26
    bl copy_str
    mov x26, x0

    ldr x0, =lbl_risk
    mov x1, x26
    bl copy_str
    mov x26, x0
    mov x0, x24
    mov x1, x26
    bl copy_str
    mov x26, x0
    ldr x0, =nl
    mov x1, x26
    bl copy_str
    mov x26, x0

    ldr x0, =lbl_status
    mov x1, x26
    bl copy_str
    mov x26, x0

    ldr x10, =out_buf
    sub x2, x26, x10
    ldr x0, =out_path
    ldr x1, =out_buf
    bl utils_write_result

    mov x0, #0
    bl utils_exit

error_argc:
    mov x0, #1
    ldr x1, =msg_err_argc
    mov x2, len_err_argc
    mov x8, #64
    svc #0
    mov x0, #1
    bl utils_exit

error_range:
    mov x0, #1
    ldr x1, =msg_err_rng
    mov x2, len_err_rng
    mov x8, #64
    svc #0
    mov x0, #1
    bl utils_exit

error_column:
    mov x0, #1
    ldr x1, =msg_err_col
    mov x2, len_err_col
    mov x8, #64
    svc #0
    mov x0, #1
    bl utils_exit

error_open:
    mov x0, #1
    ldr x1, =msg_err_opn
    mov x2, len_err_opn
    mov x8, #64
    svc #0
    mov x0, #1
    bl utils_exit

error_read:
    mov x0, #1
    ldr x1, =msg_err_read
    mov x2, len_err_read
    mov x8, #64
    svc #0
    mov x0, #1
    bl utils_exit

copy_str:
    ldrb w2, [x0]
    cbz w2, copy_str_done
    strb w2, [x1]
    add x0, x0, #1
    add x1, x1, #1
    b copy_str
copy_str_done:
    mov x0, x1
    ret
