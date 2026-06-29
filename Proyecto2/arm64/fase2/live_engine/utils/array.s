guardar_dato:
    ldr x2, [x1]

    cmp x2, #5
    bge desplazar_array
    b guardar_directo

desplazar_array:
    ldr x4, [x3, #8]
    str x4, [x3, #0]

    ldr x4, [x3, #16]
    str x4, [x3, #8]

    ldr x4, [x3, #24]
    str x4, [x3, #16]

    ldr x4, [x3, #32]
    str x4, [x3, #24]

    str x0, [x3, #32]

    ret

guardar_directo:
    mov x4, #8
    mul x5, x2, x4

    add x6, x3, x5
    str x0, [x6]

    add x2, x2, #1
    str x2, [x1]

    ret
