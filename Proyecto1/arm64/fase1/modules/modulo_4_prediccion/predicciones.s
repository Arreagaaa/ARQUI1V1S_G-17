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
out_path:   .asciz "results/resultado_prediccion.txt"
lbl_module: .asciz "MODULE=PREDICTION\n"
lbl_total:  .asciz "TOTAL_VALUES="
lbl_init:   .asciz "INITIAL_VALUE="
lbl_final:  .asciz "FINAL_VALUE="
lbl_diff:   .asciz "TOTAL_DIFF="
lbl_avg:    .asciz "AVG_CHANGE="
lbl_next:   .asciz "NEXT_VALUE="
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
out_buf:    .skip 256

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
    cmp x24, #2
    bge save_count
    b error_read
save_count:
    mov x19, x24
    mov x0, x23
    mov x8, #57
    svc #0

    ldr x9, =values_buf

    ldr x20, [x9]                    // first value
    sub x5, x19, #1
    lsl x5, x5, #3
    ldr x21, [x9, x5]               // last value (at index count-1)

    sub x22, x21, x20               // total diff

    sub x1, x19, #1                 // count - 1
    sdiv x23, x22, x1              // avg_change

    add x24, x21, x23              // next prediction

    ldr x25, =out_buf
    ldr x0, =lbl_module
    mov x1, x25
    bl copy_text
    mov x25, x0

    ldr x0, =lbl_total
    mov x1, x25
    bl copy_text
    mov x25, x0
    mov x0, x19
    mov x1, x25
    bl num_to_text
    mov x25, x0
    ldr x0, =nl
    mov x1, x25
    bl copy_text
    mov x25, x0

    ldr x0, =lbl_init
    mov x1, x25
    bl copy_text
    mov x25, x0
    mov x0, x20
    mov x1, x25
    bl num_to_text
    mov x25, x0
    ldr x0, =nl
    mov x1, x25
    bl copy_text
    mov x25, x0

    ldr x0, =lbl_final
    mov x1, x25
    bl copy_text
    mov x25, x0
    mov x0, x21
    mov x1, x25
    bl num_to_text
    mov x25, x0
    ldr x0, =nl
    mov x1, x25
    bl copy_text
    mov x25, x0

    ldr x0, =lbl_diff
    mov x1, x25
    bl copy_text
    mov x25, x0
    mov x0, x22
    mov x1, x25
    bl num_to_text
    mov x25, x0
    ldr x0, =nl
    mov x1, x25
    bl copy_text
    mov x25, x0

    ldr x0, =lbl_avg
    mov x1, x25
    bl copy_text
    mov x25, x0
    mov x0, x23
    mov x1, x25
    bl num_to_text
    mov x25, x0
    ldr x0, =nl
    mov x1, x25
    bl copy_text
    mov x25, x0

    ldr x0, =lbl_next
    mov x1, x25
    bl copy_text
    mov x25, x0
    mov x0, x24
    mov x1, x25
    bl num_to_text
    mov x25, x0
    ldr x0, =nl
    mov x1, x25
    bl copy_text
    mov x25, x0

    ldr x0, =lbl_status
    mov x1, x25
    bl copy_text
    mov x25, x0

    ldr x10, =out_buf
    sub x2, x25, x10
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

copy_text:
    ldrb w2, [x0]
    cbz w2, copy_end
    strb w2, [x1]
    add x0, x0, #1
    add x1, x1, #1
    b copy_text
copy_end:
    mov x0, x1
    ret

num_to_text:
    cmp x0, #0
    bge num_positive
    mov w2, #'-'
    strb w2, [x1]
    add x1, x1, #1
    neg x0, x0
num_positive:
    b utils_i64_to_str
