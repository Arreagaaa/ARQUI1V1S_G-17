// print entero + newline
print_uint:
    cmp x0, #0
    bge print_uint_positive
    mov x9, x0
    mov x0, #1
    ldr x1, =minus_sign
    mov x2, #1
    mov x8, #64
    svc #0
    mov x0, x9
    neg x0, x0
    b print_uint_positive
print_uint_positive:
    ldr x1, =num_buffer
    add x1, x1, #31
    mov w2, #0
    strb w2, [x1]
    mov x3, #10
    mov x4, #0
    cmp x0, #0
    bne convert_loop
    sub x1, x1, #1
    mov w2, '0'
    strb w2, [x1]
    mov x4, #1
    b write_number
convert_loop:
    udiv x9, x0, x3
    msub x6, x9, x3, x0
    add x6, x6, '0'
    sub x1, x1, #1
    strb w6, [x1]
    add x4, x4, #1
    mov x0, x9
    cbnz x0, convert_loop
write_number:
    mov x0, #1
    mov x2, x4
    mov x8, #64
    svc #0
    mov x0, #1
    ldr x1, =newline
    mov x2, #1
    mov x8, #64
    svc #0
    ret
