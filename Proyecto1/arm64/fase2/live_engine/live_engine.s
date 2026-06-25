.data

temp_ideal:
    .quad 30

msg_fan_on:
    .ascii "ACTION=FAN_ON\n"
    len_fan_on = . - msg_fan_on

msg_no_action:
    .ascii "ACTION=NO_ACTION\n"
    len_no_action = . - msg_no_action

.bss

temp_array:
    .skip 8 * 5

temp_count:
    .skip 8

input_buffer:
    .skip 64

.text
.global _start

.include "utils/atoi.s"
.include "utils/array.s"

_start:

main_loop:
    mov x0, #0
    ldr x1, =input_buffer
    mov x2, #64
    mov x8, #63
    svc #0

    cmp x0, #0
    ble end_program

    ldr x21, =input_buffer
    mov x5, #10

    bl atoi_csv
    cbz x7, main_loop

    mov x0, x10
    ldr x1, =temp_count
    ldr x3, =temp_array
    bl guardar_dato

    bl calcular_promedio

    ldr x0, =temp_ideal
    ldr x0, [x0]

    cmp x13, x0
    bgt imprimir_fan_on

    b imprimir_no_action

calcular_promedio:
    ldr x1, =temp_array
    ldr x2, =temp_count
    ldr x2, [x2]

    mov x3, #0
    mov x4, #0

sumar_loop:
    cmp x4, x2
    beq dividir_promedio

    lsl x6, x4, #3
    ldr x7, [x1, x6]
    add x3, x3, x7
    add x4, x4, #1
    b sumar_loop

dividir_promedio:
    cmp x2, #0
    beq promedio_cero

    udiv x13, x3, x2
    ret

promedio_cero:
    mov x13, #0
    ret

imprimir_fan_on:
    mov x0, #1
    ldr x1, =msg_fan_on
    mov x2, len_fan_on
    mov x8, #64
    svc #0
    b main_loop

imprimir_no_action:
    mov x0, #1
    ldr x1, =msg_no_action
    mov x2, len_no_action
    mov x8, #64
    svc #0
    b main_loop

end_program:
    mov x0, #0
    mov x8, #93
    svc #0
