.global atoi_csv
atoi_csv:
    mov x10, #0
    mov x7, #0

atoi_loop:
    ldrb w23, [x21], #1

    cmp w23, '0'
    blt atoi_done

    cmp w23, '9'
    bgt atoi_done

    sub w23, w23, '0'

    mov x4, x10
    mul x10, x4, x5

    add x10, x10, x23

    mov x7, #1

    b atoi_loop

atoi_done:
    ret
