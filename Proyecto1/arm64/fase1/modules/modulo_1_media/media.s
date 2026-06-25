.global _start

.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

.equ MAX_VALUES, 30

.data
out_path: .asciz "results/resultado_media.txt"
mod_name: .asciz "MODULE=WEIGHTED_MEAN\n"
total_v:  .asciz "TOTAL_VALUES="
lbl_sumx: .asciz "SUM_X="
lbl_wsum: .asciz "WEIGHT_SUM="
lbl_mean: .asciz "WEIGHTED_MEAN="
nl:       .asciz "\n"

.bss
values_buf:
    .skip 8 * MAX_VALUES

out_buf:
    .skip 256

.text
_start:
    bl utils_open_csv
    mov x19, x0

    mov x0, x19
    mov x1, #1
    ldr x2, =values_buf
    mov x3, #1
    mov x4, #MAX_VALUES
    bl utils_read_int_column
    mov x20, x0

    mov x0, x19
    bl utils_close_csv

    add x1, x20, #1
    mul x23, x20, x1
    mov x0, #2
    sdiv x23, x23, x0

    ldr x0, =values_buf
    mov x1, x20
    bl sum_values
    mov x21, x0

    ldr x0, =values_buf
    mov x1, x20
    bl weighted_mean
    mov x22, x0

    ldr x9, =out_buf
    ldr x0, =mod_name

copy_mod:
    ldrb w2, [x0]
    cbz w2, copy_mod_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_mod

copy_mod_end:
    ldr x0, =total_v

copy_total:
    ldrb w2, [x0]
    cbz w2, copy_total_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_total

copy_total_end:
    mov x0, x20
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0

    ldr x0, =nl

copy_nl_tot:
    ldrb w2, [x0]
    cbz w2, copy_nl_tot_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_nl_tot

copy_nl_tot_end:
    ldr x0, =lbl_sumx

copy_sumx:
    ldrb w2, [x0]
    cbz w2, copy_sumx_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_sumx

copy_sumx_end:
    mov x0, x21
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0

    ldr x0, =nl

copy_nl1:
    ldrb w2, [x0]
    cbz w2, copy_nl1_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_nl1

copy_nl1_end:
    ldr x0, =lbl_wsum

copy_wsum:
    ldrb w2, [x0]
    cbz w2, copy_wsum_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_wsum

copy_wsum_end:
    mov x0, x23
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0

    ldr x0, =nl

copy_nl_ws:
    ldrb w2, [x0]
    cbz w2, copy_nl_ws_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_nl_ws

copy_nl_ws_end:
    ldr x0, =lbl_mean

copy_mean:
    ldrb w2, [x0]
    cbz w2, copy_mean_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_mean

copy_mean_end:
    mov x0, x22
    mov x1, x9
    bl utils_i64_to_str
    mov x9, x0

    ldr x0, =nl

copy_nl2:
    ldrb w2, [x0]
    cbz w2, copy_nl2_end
    strb w2, [x9]
    add x0, x0, #1
    add x9, x9, #1
    b copy_nl2

copy_nl2_end:
    ldr x10, =out_buf
    sub x23, x9, x10

    ldr x0, =out_path
    ldr x1, =out_buf
    mov x2, x23
    bl utils_write_result

    mov x0, #0
    bl utils_exit

sum_values:
    stp x29, x30, [sp, #-16]!
    mov x5, x0
    mov x6, x1
    mov x2, #0
    mov x3, #0

sum_loop:
    cbz x6, sum_done
    ldr x4, [x5, x2, lsl #3]
    add x3, x3, x4
    add x2, x2, #1
    sub x6, x6, #1
    b sum_loop

sum_done:
    mov x0, x3
    ldp x29, x30, [sp], #16
    ret

weighted_mean:
    stp x29, x30, [sp, #-16]!
    mov x5, x0
    mov x6, x1
    mov x2, #0
    mov x3, #0

wm_loop:
    cbz x6, wm_done
    ldr x4, [x5, x2, lsl #3]
    add x7, x2, #1
    mul x4, x4, x7
    add x3, x3, x4
    add x2, x2, #1
    sub x6, x6, #1
    b wm_loop

wm_done:
    mov x4, x1
    add x7, x4, #1
    mul x7, x4, x7
    mov x8, #2
    sdiv x7, x7, x8
    sdiv x0, x3, x7
    ldp x29, x30, [sp], #16
    ret
