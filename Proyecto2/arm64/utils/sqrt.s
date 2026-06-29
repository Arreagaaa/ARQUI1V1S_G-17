// raiz cuadrada entera
int_sqrt:
    mov x1, #1
sqrt_loop:
    mul x2, x1, x1
    cmp x2, x0
    ble sqrt_inc
    b sqrt_end
sqrt_inc:
    add x1, x1, #1
    b sqrt_loop
sqrt_end:
    sub x0, x1, #1
    ret
