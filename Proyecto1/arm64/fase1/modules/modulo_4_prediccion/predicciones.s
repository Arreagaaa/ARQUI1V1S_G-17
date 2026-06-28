.global _start

.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

.equ N_VALUES, 30
.equ N_MINUS_1, 29
.equ COL_PRED, 4

.data
out_path:   .asciz "results/resultado_prediccion.txt"
mod_name:   .asciz "MODULE=PREDICTION\n"
total_v:    .asciz "TOTAL_VALUES=30\n"
lbl_init:   .asciz "INITIAL_VALUE="
lbl_final:  .asciz "FINAL_VALUE="
lbl_diff:   .asciz "TOTAL_DIFF="
lbl_avg:    .asciz "AVG_CHANGE="
lbl_next:   .asciz "NEXT_VALUE="
nl:         .asciz "\n"

.bss
values_buf:
    .skip 8 * N_VALUES

out_buf:
    .skip 256

.text
_start:
    bl utils_open_csv
    mov x19, x0

    mov x1, #COL_PRED
    mov x0, x19
    ldr x2, =values_buf
    mov x3, #1
    mov x4, #N_VALUES
    bl utils_read_int_column

    cmp x0, #N_VALUES
    beq pred_f1_read_ok
    b error
pred_f1_read_ok:

    mov x0, x19
    bl utils_close_csv

    ldr x9, =values_buf

    ldr x20, [x9]
    ldr x21, [x9, #(29 * 8)]

    sub x22, x21, x20

    mov x1, #N_MINUS_1
    sdiv x23, x22, x1

    add x24, x21, x23

    ldr x25, =out_buf

    ldr x0, =mod_name
    mov x1, x25
    bl copy_text
    mov x25, x0

    ldr x0, =total_v
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

    ldr x10, =out_buf
    sub x2, x25, x10

    ldr x0, =out_path
    ldr x1, =out_buf
    bl utils_write_result

    mov x0, #0
    bl utils_exit

error:
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
    b num_negative
num_negative:

    mov w2, #'-'
    strb w2, [x1]
    add x1, x1, #1
    neg x0, x0

num_positive:
    b utils_i64_to_str