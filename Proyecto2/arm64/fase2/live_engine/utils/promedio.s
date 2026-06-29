// promedio(buffer, &count)
calcular_promedio:
    ldr x2, [x1]
    cbz x2, prom_cero
    mov x3, x0
    mov x4, #0
    mov x5, #0
prom_loop:
    ldr x6, [x3, x5, lsl #3]
    add x4, x4, x6
    add x5, x5, #1
    cmp x5, x2
    bge prom_done
    b prom_loop
prom_done:
    sdiv x0, x4, x2
    ret
prom_cero:
    mov x0, #0
    ret
