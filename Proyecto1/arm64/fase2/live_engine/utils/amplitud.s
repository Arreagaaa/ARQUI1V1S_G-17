// amplitud(buffer, &count)
calcular_amplitud:
    ldr x2, [x1]
    cmp x2, #1
    blt amplitud_cero
    mov x3, x0
    mov x4, #0
    ldr x5, [x3]
    ldr x6, [x3]
amplitud_loop:
    add x4, x4, #1
    cmp x4, x2
    bge amplitud_done
    ldr x7, [x3, x4, lsl #3]
    cmp x7, x5
    ble amp_check_min
    mov x5, x7
amp_check_min:
    cmp x7, x6
    bge amplitud_loop
    mov x6, x7
    b amplitud_loop
amplitud_done:
    sub x0, x5, x6
    ret
amplitud_cero:
    mov x0, #0
    ret
