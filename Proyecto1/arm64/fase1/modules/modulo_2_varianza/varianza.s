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
out_path:   .asciz "results/resultado_varianza.txt"
lbl_module: .asciz "MODULE=VARIANCE\n"
lbl_total:  .asciz "TOTAL_VALUES="
lbl_mean:   .asciz "MEAN="
lbl_var:    .asciz "VARIANCE="
lbl_std:    .asciz "STD_DEV="
lbl_status: .asciz "STATUS=OK\n"
nl:         .asciz "\n"

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
values_buf: .skip 8 * MAX_VALUES
out_buf:    .skip 512

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
    bge close_file
    b error_read
close_file:
    mov x0, x23
    mov x8, #57
    svc #0

    ldr x0, =values_buf
    mov x6, x24
    bl mean_value
    mov x25, x0

    ldr x0, =values_buf
    mov x1, x25
    mov x6, x24
    bl variance_value
    mov x26, x0

    mov x0, x26
    bl isqrt_value
    mov x27, x0

    ldr x9, =out_buf
    ldr x0, =lbl_module
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_total
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x24
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_mean
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x25
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_var
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x26
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0
    ldr x0, =nl
    mov x1, x9
    bl copy_str
    mov x9, x0

    ldr x0, =lbl_std
    mov x1, x9
    bl copy_str
    mov x9, x0
    mov x0, x27
    mov x1, x9
    bl utils_i64_to_str
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

mean_value:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x1, x0
    mov x2, #0
    mov x3, #0
    mov x5, x6
mean_loop:
    cbz x6, mean_done
    ldr x4, [x1, x3, lsl #3]
    add x2, x2, x4
    add x3, x3, #1
    sub x6, x6, #1
    b mean_loop
mean_done:
    sdiv x0, x2, x5
    ldp x29, x30, [sp], #16
    ret

variance_value:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x2, x0
    mov x7, x1
    mov x3, #0
    mov x4, #0
    mov x8, x6
var_loop:
    cbz x6, var_done
    ldr x5, [x2, x4, lsl #3]
    sub x5, x5, x7
    mul x5, x5, x5
    add x3, x3, x5
    add x4, x4, #1
    sub x6, x6, #1
    b var_loop
var_done:
    mov x5, x8
    sdiv x0, x3, x5
    ldp x29, x30, [sp], #16
    ret

isqrt_value:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    cmp x0, #0
    beq isqrt_ret
    cmp x0, #1
    beq isqrt_ret
    mov x2, x0
    mov x1, x0
isqrt_iter:
    sdiv x3, x2, x1
    add x3, x3, x1
    lsr x3, x3, #1
    cmp x3, x1
    bge isqrt_conv
    mov x1, x3
    b isqrt_iter
isqrt_conv:
    mov x0, x1
isqrt_ret:
    ldp x29, x30, [sp], #16
    ret

copy_str:
    ldrb w2, [x0]
    cbz w2, copy_end
    strb w2, [x1]
    add x0, x0, #1
    add x1, x1, #1
    b copy_str
copy_end:
    mov x0, x1
    ret
