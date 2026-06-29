.extern utils_parse_i64
.extern utils_validate_range
.extern utils_validate_column
.extern utils_read_int_column
.extern utils_i64_to_str
.extern utils_write_result
.extern utils_exit

.equ MAX_VALUES, 256

.data
out_path:	.asciz "results/resultado_tendencia.txt"
lbl_module:	.asciz "MODULE=ADVANCED_TREND\n"
lbl_total:	.asciz "TOTAL_VALUES="
lbl_incr:	.asciz "INCREMENTS="
lbl_decr:	.asciz "DECREMENTS="
lbl_maxup:	.asciz "MAX_UP_STREAK="
lbl_maxdn:	.asciz "MAX_DOWN_STREAK="
lbl_accum:	.asciz "ACCUM_DIFF="
lbl_trend:	.asciz "TREND="
lbl_status:	.asciz "STATUS=OK\n"
str_up:		.asciz "UP"
str_down:	.asciz "DOWN"
str_stable:	.asciz "STABLE"
nl:		.asciz "\n"
minus_sign:	.asciz "-"

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
values_buf:    .skip 8 * MAX_VALUES
out_buf:       .skip 512

.text
.global _start

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
    cmp x24, #2
    bge save_count
    b error_read
save_count:
    mov x19, x24
    mov x0, x23
    mov x8, #57
    svc #0

    ldr x0, =values_buf
    sub x1, x19, #1
    bl contar_cambios
    // x20=INCREMENTS  x21=DECREMENTS  x22=MAX_UP  x23=MAX_DOWN

    mov x0, x20
    mov x1, x21
    bl calcular_tendencia
    mov x24, x0               // ACCUM_DIFF
    mov x25, x1               // ptr string TREND

    ldr x9, =out_buf

    ldr x0, =lbl_module
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_total
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x19
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_incr
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x20
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_decr
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x21
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_maxup
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x22
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_maxdn
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x23
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_accum
    mov x1, x9
    bl copy_str
    mov x9, x0
    cmp x24, #0
    bge accum_pos
    b accum_neg
accum_neg:
    ldr x0, =minus_sign
    mov x1, x9
    bl copy_str
    mov x9, x0
    neg x0, x24
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    b accum_nl
accum_pos:
    mov x0, x24
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
accum_nl:
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_trend
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x25
    mov x1, x9
    bl copy_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_status
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x10, =out_buf
    sub x2, x9, x10
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

contar_cambios:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x8, x1                  // pairs = count - 1

    mov x20, #0
    mov x21, #0
    mov x22, #0
    mov x23, #0
    mov x14, #0
    mov x15, #0

    mov x9, x0
    mov x10, #0

    ldr x11, [x9]

cc_loop:
    cmp x10, x8
    bge cc_done

    add x10, x10, #1
    lsl x16, x10, #3
    ldr x12, [x9, x16]

    cmp x12, x11
    ble check_down
    b cc_sube
check_down:
    cmp x12, x11
    bge cc_next
    b cc_baja

    mov x14, #0
    mov x15, #0
    b cc_next

cc_sube:
    add x20, x20, #1
    add x14, x14, #1
    mov x15, #0
    cmp x14, x22
    ble cc_next
    mov x22, x14
    b cc_next

cc_baja:
    add x21, x21, #1
    add x15, x15, #1
    mov x14, #0
    cmp x15, x23
    ble cc_next
    mov x23, x15

cc_next:
    mov x11, x12
    b cc_loop

cc_done:
    ldp x29, x30, [sp], #16
    ret

calcular_tendencia:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    sub x0, x0, x1

    cmp x0, #0
    ble ct_check_down
    b ct_up
ct_check_down:
    cmp x0, #0
    bge ct_stable
    b ct_down
ct_stable:
    ldr x1, =str_stable
    b ct_fin
ct_up:
    ldr x1, =str_up
    b ct_fin
ct_down:
    ldr x1, =str_down
ct_fin:
    ldp x29, x30, [sp], #16
    ret

copy_str:
    ldrb w2, [x0]
    cbz w2, cs_done
    strb w2, [x1]
    add x0, x0, #1
    add x1, x1, #1
    b copy_str
cs_done:
    mov x0, x1
    ret
