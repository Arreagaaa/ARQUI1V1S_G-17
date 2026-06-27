// tendencia(buffer, &count)
calcular_tendencia:
    ldr x2, [x1]
    cmp x2, #2
    blt tendencia_cero
    mov x3, x0
    mov x4, #0
    mov x5, #0
tendencia_loop:
    add x6, x5, #1
    cmp x6, x2
    bge tendencia_done
    ldr x7, [x3, x6, lsl #3]
    ldr x8, [x3, x5, lsl #3]
    sub x7, x7, x8
    add x4, x4, x7
    add x5, x5, #1
    b tendencia_loop
tendencia_done:
    mov x0, x4
    ret
tendencia_cero:
    mov x0, #0
    ret
