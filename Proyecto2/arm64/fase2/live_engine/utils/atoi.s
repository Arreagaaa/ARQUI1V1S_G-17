atoi_csv:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #-16]!
    mov x19, x21          // backup del puntero inicial

    // verificar que el caracter actual sea digito
    ldrb w23, [x21]
    cmp w23, '0'
    blt atoi_fail
    cmp w23, '9'
    bgt atoi_fail

    mov x0, x21
    bl utils_parse_i64
    mov x10, x0           // valor parseado
    mov x7, #1            // exito

    // avanzar x21 hasta la coma o fin de linea
    mov x20, x19
atoi_skip:
    ldrb w23, [x20], #1
    cmp w23, ','
    beq atoi_found
    cmp w23, #10           // newline
    beq atoi_found
    cmp w23, #0            // null terminator
    beq atoi_found
    b atoi_skip

atoi_found:
    mov x21, x20          // x21 apunta justo despues de la coma
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

atoi_fail:
    mov x10, #0
    mov x7, #0
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret
