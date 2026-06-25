.equ STDIN, 0
.equ STDOUT, 1
.equ BUF_SIZE, 256

.data
    csv_path: .asciz "lecturas.csv"
    msg_nl:   .asciz "\n"

.bss
    line_buf: .skip BUF_SIZE

.text
.global utils_open_csv
utils_open_csv:
    mov x0, #-100
    ldr x1, =csv_path
    mov x2, #0
    mov x3, #0
    mov x8, #56
    svc #0
    cmp x0, #0
    blt open_fail
    ret

open_fail:
    mov x0, #1
    mov x8, #93
    svc #0

.global utils_read_line
utils_read_line:
    mov x5, x0
    mov x6, x1
    mov x3, #0
    sub x4, x2, #1

read_loop:
    cmp x3, x4
    bge read_done

    mov x0, x5
    add x1, x6, x3
    mov x2, #1
    mov x8, #63
    svc #0

    cmp x0, #0
    ble read_done

    ldrb w7, [x6, x3]
    add x3, x3, #1
    cmp w7, #'\n'
    beq read_done
    b read_loop

read_done:
    strb wzr, [x6, x3]
    mov x0, x3
    ret

.global utils_parse_i64
utils_parse_i64:
    mov x1, #0
    mov x2, #10

up_loop:
    ldrb w3, [x0]
    cmp w3, #'0'
    blt up_done
    cmp w3, #'9'
    bgt up_done
    mul x1, x1, x2
    sub w3, w3, #'0'
    add x1, x1, x3
    add x0, x0, #1
    b up_loop

up_done:
    mov x0, x1
    ret

read_column:
    mov x2, x0
    mov x3, #0
    mov x4, x1

skip_column:
    cmp x3, x4
    blt skip_more
    b read_value

skip_more:
    ldrb w5, [x2]
    cbz w5, zero_value
    cmp w5, #'\n'
    beq zero_value
    cmp w5, #','
    bne skip_next
    add x2, x2, #1
    add x3, x3, #1
    b skip_column

skip_next:
    add x2, x2, #1
    b skip_column

read_value:
    mov x0, x2
    b utils_parse_i64

zero_value:
    mov x0, #0
    ret

.global utils_read_int_column
utils_read_int_column:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!

    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, #1
    mov x25, #0

    mov x0, x19
    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line

rc_read_next:
    mov x0, x19
    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line
    cmp x0, #0
    ble rc_done
    cmp x24, x22
    blt rc_skip
    cmp x24, x23
    bgt rc_done
    ldr x0, =line_buf
    mov x1, x20
    bl read_column
    str x0, [x21, x25, lsl #3]
    add x25, x25, #1

rc_skip:
    add x24, x24, #1
    b rc_read_next

rc_done:
    mov x0, x25
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.global utils_count_lines
utils_count_lines:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!

    mov x19, x0
    mov x20, #0

    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line

ucl_loop:
    mov x0, x19
    ldr x1, =line_buf
    mov x2, #BUF_SIZE
    bl utils_read_line
    cmp x0, #0
    ble ucl_done
    add x20, x20, #1
    b ucl_loop

ucl_done:
    mov x0, x20
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.global utils_close_csv
utils_close_csv:
    mov x8, #57
    svc #0
    ret

.global utils_write_result
utils_write_result:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0
    mov x20, x1
    mov x21, x2

    mov x0, #-100
    mov x1, x19
    mov x2, #(1 | 64 | 512)
    mov x3, #0644
    mov x8, #56
    svc #0
    cmp x0, #0
    blt write_fail

    mov x19, x0
    mov x0, x19
    mov x1, x20
    mov x2, x21
    mov x8, #64
    svc #0

    mov x0, x19
    mov x8, #57
    svc #0

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

write_fail:
    mov x0, #1
    mov x8, #93
    svc #0

.global utils_i64_to_str
utils_i64_to_str:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!

    mov x19, x0
    mov x20, x1
    cbnz x19, uis_nonzero
    mov w2, #'0'
    strb w2, [x20]
    add x0, x20, #1
    b uis_done

uis_nonzero:
    sub sp, sp, #32
    mov x2, sp
    mov x3, #0
    mov x4, #10

uis_digit:
    udiv x5, x19, x4
    msub x6, x5, x4, x19
    add w6, w6, #'0'
    strb w6, [x2, x3]
    add x3, x3, #1
    mov x19, x5
    cbnz x19, uis_digit

    mov x7, #0

uis_copy:
    sub x3, x3, #1
    ldrb w6, [x2, x3]
    strb w6, [x20, x7]
    add x7, x7, #1
    cbnz x3, uis_copy

    add sp, sp, #32
    add x0, x20, x7

uis_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.global utils_print_string
utils_print_string:
    mov x2, x1
    mov x1, x0
    mov x0, #STDOUT
    mov x8, #64
    svc #0
    ret

.global utils_print_newline
utils_print_newline:
    mov x0, #STDOUT
    ldr x1, =msg_nl
    mov x2, #1
    mov x8, #64
    svc #0
    ret

.global utils_print_i64
utils_print_i64:
    stp x29, x30, [sp, #-16]!
    sub sp, sp, #32
    mov x2, sp
    mov x1, x2
    bl utils_i64_to_str
    mov x1, x2
    sub x2, x0, x1
    mov x0, #STDOUT
    mov x8, #64
    svc #0
    add sp, sp, #32
    ldp x29, x30, [sp], #16
    ret

.global utils_exit
utils_exit:
    mov x8, #93
    svc #0
