.global _start 

.extern utils_parse_i64
.extern utils_validate_range
.extern utils_validate_column
.extern utils_read_int_column
.extern utils_count_lines
.extern utils_close_csv

.include "utils/print_uint.s"

.equ MAX_VALUES, 2000

.data
lbl_calc:      .ascii "CALC=PREDICTION\n";       len_calc = . - lbl_calc
lbl_col:       .ascii "COLUMN=";                 len_col = . - lbl_col
lbl_ws:        .ascii "WINDOW_START=";           len_ws = . - lbl_ws
lbl_we:        .ascii "WINDOW_END=";             len_we = . - lbl_we
lbl_cnt:       .ascii "COUNT=";                  len_cnt = . - lbl_cnt
lbl_k:         .ascii "K=";                      len_k = . - lbl_k
lbl_slope:     .ascii "SLOPE_X100=";             len_slope = . - lbl_slope
lbl_intercept: .ascii "INTERCEPT_X100=";         len_intercept = . - lbl_intercept
lbl_pred:      .ascii "PREDICTED_";              len_pred = . - lbl_pred
lbl_eq:        .ascii "=";                       len_eq = . - lbl_eq
lbl_ok:        .ascii "STATUS=OK\n";             len_ok = . - lbl_ok

minus_sign:    .ascii "-"
newline:       .ascii "\n"

col_temp: .asciz "TEMP"
col_hum:  .asciz "HUM_AIRE"
col_s1:   .asciz "SOIL1"
col_s2:   .asciz "SOIL2"
col_luz:  .asciz "LUZ"
col_gas:  .asciz "GAS"
col_names: .quad col_temp, col_hum, col_s1, col_s2, col_luz, col_gas

msg_err_argc: .ascii "STATUS=ERROR\nERROR=INVALID_ARGS\nDETAIL=EXPECTED_PATH_START_END_COLUMN_OPTIONAL_K\n"
len_err_argc = . - msg_err_argc

msg_err_rng: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=START_END_INVALID\n"
len_err_rng = . - msg_err_rng

msg_err_col: .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_MUST_BE_1_TO_6\n"
len_err_col = . - msg_err_col

msg_err_opn: .ascii "STATUS=ERROR\nERROR=FILE_NOT_FOUND\nDETAIL=COULD_NOT_OPEN_FILE\n"
len_err_opn = . - msg_err_opn

msg_err_eof: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=END_LINE_EXCEEDS_FILE_LENGTH\n"
len_err_eof = . - msg_err_eof

msg_err_count: .ascii "STATUS=ERROR\nERROR=INVALID_COUNT\nDETAIL=RANGE_OUT_OF_FILE_OR_TOO_LARGE\n"
len_err_count = . - msg_err_count

msg_err_min: .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=PREDICTION_REQUIRES_AT_LEAST_2_VALUES\n"
len_err_min = . - msg_err_min

msg_err_k: .ascii "STATUS=ERROR\nERROR=INVALID_K\nDETAIL=K_MUST_BE_GREATER_THAN_ZERO\n"
len_err_k = . - msg_err_k

msg_err_div: .ascii "STATUS=ERROR\nERROR=DIVISION_BY_ZERO\nDETAIL=REGRESSION_DENOMINATOR_ZERO\n"
len_err_div = . - msg_err_div

.bss
values_buf:
    .skip 8 * MAX_VALUES

num_buffer:
    .skip 32

.text
_start:
    ldr x0, [sp]
    cmp x0, #5
    blt error_argc

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

    mov x23, #5

    ldr x0, [sp]
    cmp x0, #6
    blt args_ready

    ldr x0, [sp, #48]
    bl utils_parse_i64
    mov x23, x0

args_ready:
    cmp x23, #1
    blt error_k

    mov x0, x20
    mov x1, x21
    bl utils_validate_range
    cbnz x0, error_range

    mov x0, x22
    bl utils_validate_column
    cbnz x0, error_column

    sub x26, x21, x20
    add x26, x26, #1
    cmp x26, #MAX_VALUES
    bgt error_count

    mov x0, #-100
    mov x1, x19
    mov x2, #0
    mov x3, #0
    mov x8, #56
    svc #0
    cmp x0, #0
    blt error_open

    mov x24, x0
    mov x0, x24
    bl utils_count_lines
    mov x25, x0

    mov x0, x24
    bl utils_close_csv

    cmp x21, x25
    bgt error_eof

    mov x0, #-100
    mov x1, x19
    mov x2, #0
    mov x3, #0
    mov x8, #56
    svc #0
    cmp x0, #0
    blt error_open

    mov x24, x0

    mov x0, x24
    mov x1, x22
    ldr x2, =values_buf
    mov x3, x20
    mov x4, x21
    bl utils_read_int_column
    mov x25, x0

    mov x0, x24
    bl utils_close_csv

    cmp x25, x26
    b.ne error_count

    cmp x25, #2
    blt error_min_values

    ldr x10, =values_buf
    mov x11, #0

    mov x19, #0
    mov x26, #0
    mov x27, #0
    mov x28, #0

sum_loop:
    cmp x11, x25
    bge calc_regression

    ldr x12, [x10, x11, lsl #3]

    add x26, x26, x11
    add x27, x27, x12

    mul x13, x11, x12
    add x28, x28, x13

    mul x13, x11, x11
    add x19, x19, x13

    add x11, x11, #1
    b sum_loop

calc_regression:
    mul x14, x25, x28
    mul x15, x26, x27
    sub x14, x14, x15

    mul x15, x25, x19
    mul x16, x26, x26
    sub x15, x15, x16

    cbz x15, error_divzero

    mov x16, #100
    mul x14, x14, x16
    sdiv x24, x14, x15

    mul x14, x27, x16
    mul x15, x24, x26
    sub x14, x14, x15
    sdiv x28, x14, x25

    add x15, x25, x23
    mul x14, x24, x15
    add x14, x14, x28
    sdiv x27, x14, x16

    ldr x1, =lbl_calc
    mov x2, len_calc
    bl print_label

    ldr x1, =lbl_col
    mov x2, len_col
    bl print_label
    mov x0, x22
    bl print_col_name

    ldr x1, =lbl_ws
    mov x2, len_ws
    bl print_label
    mov x0, x20
    bl print_uint

    ldr x1, =lbl_we
    mov x2, len_we
    bl print_label
    mov x0, x21
    bl print_uint

    ldr x1, =lbl_cnt
    mov x2, len_cnt
    bl print_label
    mov x0, x25
    bl print_uint

    ldr x1, =lbl_k
    mov x2, len_k
    bl print_label
    mov x0, x23
    bl print_uint

    ldr x1, =lbl_slope
    mov x2, len_slope
    bl print_label
    mov x0, x24
    bl print_int

    ldr x1, =lbl_intercept
    mov x2, len_intercept
    bl print_label
    mov x0, x28
    bl print_int

    ldr x1, =lbl_pred
    mov x2, len_pred
    bl print_label

    mov x0, x23
    bl print_uint_inline

    ldr x1, =lbl_eq
    mov x2, len_eq
    bl print_label

    mov x0, x27
    bl print_int

    ldr x1, =lbl_ok
    mov x2, len_ok
    bl print_label

    mov x0, #0
    mov x8, #93
    svc #0

print_col_name:
    stp x30, x19, [sp, #-16]!

    sub x19, x0, #1
    ldr x1, =col_names
    ldr x1, [x1, x19, lsl #3]
    bl write_str

    ldr x1, =newline
    mov x2, #1
    bl print_label

    ldp x30, x19, [sp], #16
    ret

write_str:
    stp x30, x19, [sp, #-16]!

    mov x19, x1
    mov x2, #0

ws_len:
    ldrb w3, [x19, x2]
    cbz w3, ws_write
    add x2, x2, #1
    b ws_len

ws_write:
    mov x0, #1
    mov x1, x19
    mov x8, #64
    svc #0

    ldp x30, x19, [sp], #16
    ret

print_label:
    mov x0, #1
    mov x8, #64
    svc #0
    ret

print_int:
    stp x30, x19, [sp, #-16]!

    cmp x0, #0
    bge print_int_pos

    mov x19, x0

    mov x0, #1
    ldr x1, =minus_sign
    mov x2, #1
    mov x8, #64
    svc #0

    neg x0, x19

print_int_pos:
    bl print_uint

    ldp x30, x19, [sp], #16
    ret

print_uint_inline:
    stp x30, x19, [sp, #-16]!

    ldr x1, =num_buffer
    add x1, x1, #31

    mov w2, #0
    strb w2, [x1]

    mov x3, #10
    mov x4, #0

    cmp x0, #0
    bne pui_loop

    sub x1, x1, #1
    mov w2, #'0'
    strb w2, [x1]
    mov x4, #1
    b pui_write

pui_loop:
    udiv x5, x0, x3
    msub x6, x5, x3, x0
    add x6, x6, #'0'

    sub x1, x1, #1
    strb w6, [x1]

    add x4, x4, #1
    mov x0, x5
    cbnz x0, pui_loop

pui_write:
    mov x0, #1
    mov x2, x4
    mov x8, #64
    svc #0

    ldp x30, x19, [sp], #16
    ret

error_argc:
    ldr x1, =msg_err_argc
    mov x2, len_err_argc
    b error_exit

error_range:
    ldr x1, =msg_err_rng
    mov x2, len_err_rng
    b error_exit

error_column:
    ldr x1, =msg_err_col
    mov x2, len_err_col
    b error_exit

error_open:
    ldr x1, =msg_err_opn
    mov x2, len_err_opn
    b error_exit

error_eof:
    ldr x1, =msg_err_eof
    mov x2, len_err_eof
    b error_exit

error_count:
    ldr x1, =msg_err_count
    mov x2, len_err_count
    b error_exit

error_min_values:
    ldr x1, =msg_err_min
    mov x2, len_err_min
    b error_exit

error_k:
    ldr x1, =msg_err_k
    mov x2, len_err_k
    b error_exit

error_divzero:
    ldr x1, =msg_err_div
    mov x2, len_err_div

error_exit:
    mov x0, #1
    mov x8, #64
    svc #0

    mov x0, #1
    mov x8, #93
    svc #0
