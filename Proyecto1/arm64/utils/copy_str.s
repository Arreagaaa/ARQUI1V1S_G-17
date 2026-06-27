// copia string
copy_str:
    ldrb w2, [x0]
    cbz w2, copy_end
    strb w2, [x1]
    add x0, x0, #1
    add x1, x1, #1
    b copy_str
copy_end:
    mov x0, x1
    ret
