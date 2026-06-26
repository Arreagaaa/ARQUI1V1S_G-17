.data
.align 3

// etiquetas de salida formato Fase 2
msg_action_led_green:
    .ascii "ACTION=LED_GREEN\n"
    len_action_led_green = . - msg_action_led_green

msg_action_no_action:
    .ascii "ACTION=NO_ACTION\n"
    len_action_no_action = . - msg_action_no_action

msg_target_general:
    .ascii "TARGET=GENERAL\n"
    len_target_general = . - msg_target_general

msg_target_none:
    .ascii "TARGET=NONE\n"
    len_target_none = . - msg_target_none

msg_risk_low:
    .ascii "RISK=LOW\n"
    len_risk_low = . - msg_risk_low

msg_reason_normal:
    .ascii "REASON=NORMAL_CONDITIONS\n"
    len_reason_normal = . - msg_reason_normal

msg_reason_manual:
    .ascii "REASON=MANUAL_MODE\n"
    len_reason_manual = . - msg_reason_manual

msg_label_value:
    .ascii "VALUE="
    len_label_value = . - msg_label_value

msg_label_indicator:
    .ascii "INDICATOR="
    len_label_indicator = . - msg_label_indicator

msg_status_ok:
    .ascii "STATUS=OK\n"
    len_status_ok = . - msg_status_ok

msg_error_input:
    .ascii "STATUS=ERROR\nERROR=INVALID_INPUT\nDETAIL=EXPECTED_7_FIELDS\n"
    len_error_input = . - msg_error_input

newline:
    .ascii "\n"

.bss
.align 3

// buffers circulares de 5 posiciones cada uno (8 bytes por slot)
// uno por sensor: temp, humedad, suelo1, suelo2, luz, gas
temp_buffer:
    .skip 8 * 5

temp_count:
    .skip 8

hum_buffer:
    .skip 8 * 5

hum_count:
    .skip 8

soil1_buffer:
    .skip 8 * 5

soil1_count:
    .skip 8

soil2_buffer:
    .skip 8 * 5

soil2_count:
    .skip 8

luz_buffer:
    .skip 8 * 5

luz_count:
    .skip 8

gas_buffer:
    .skip 8 * 5

gas_count:
    .skip 8

input_buffer:
    .skip 64

num_buffer:
    .skip 32

.text
.global _start

.include "utils/atoi.s"
.include "utils/array.s"

_start:
    // limpiar toda el area .bss (buffers y contadores)
    ldr x0, =temp_buffer
    ldr x1, =num_buffer
    add x1, x1, #32
    sub x1, x1, x0
    mov x2, #0

zero_bss:
    cmp x1, #8
    blt zero_bss_done
    str x2, [x0], #8
    sub x1, x1, #8
    b zero_bss

zero_bss_done:

// ciclo principal: leer stdin, parsear, guardar, decidir, imprimir
main_loop:
    // leer entrada desde stdin (hasta 64 bytes)
    mov x0, #0
    ldr x1, =input_buffer
    mov x2, #64
    mov x8, #63
    svc #0

    cmp x0, #0
    bgt main_loop_proceed
    b end_program

main_loop_proceed:
    ldr x21, =input_buffer

    // si el primer caracter es 'n', salir
    ldrb w0, [x21]
    cmp w0, 'n'
    beq end_program

    // parsear 7 campos CSV con atoi_csv
    // x5 se reinicia cada vez porque guardar_dato lo modifica
    mov x5, #10

    bl atoi_csv // temp
    cbz x7, print_error
    mov x9, x10

    bl atoi_csv // humedad
    cbz x7, print_error
    mov x18, x10

    bl atoi_csv // suelo 1
    cbz x7, print_error
    mov x11, x10

    bl atoi_csv // suelo 2
    cbz x7, print_error
    mov x12, x10

    bl atoi_csv // luz
    cbz x7, print_error
    mov x13, x10

    bl atoi_csv // gas
    cbz x7, print_error
    mov x14, x10

    bl atoi_csv // modo (0=auto, 1=manual)
    cbz x7, print_error
    mov x15, x10

    // guardar cada sensor en su buffer circular
    mov x0, x9
    ldr x1, =temp_count
    ldr x3, =temp_buffer
    bl guardar_dato

    mov x0, x18
    ldr x1, =hum_count
    ldr x3, =hum_buffer
    bl guardar_dato

    mov x0, x11
    ldr x1, =soil1_count
    ldr x3, =soil1_buffer
    bl guardar_dato

    mov x0, x12
    ldr x1, =soil2_count
    ldr x3, =soil2_buffer
    bl guardar_dato

    mov x0, x13
    ldr x1, =luz_count
    ldr x3, =luz_buffer
    bl guardar_dato

    mov x0, x14
    ldr x1, =gas_count
    ldr x3, =gas_buffer
    bl guardar_dato

    // decision basada en modo
    // auto (0) = LED_GREEN, manual (1) = NO_ACTION
    // version 50%: sin cadena de prioridades ni calculos
    cmp x15, #0
    bne imprimir_no_action

imprimir_led_green:
    ldr x1, =msg_action_led_green
    mov x2, len_action_led_green
    bl print_string
    ldr x1, =msg_target_general
    mov x2, len_target_general
    bl print_string
    ldr x1, =msg_risk_low
    mov x2, len_risk_low
    bl print_string
    ldr x1, =msg_reason_normal
    mov x2, len_reason_normal
    bl print_string
    mov x0, #0
    bl print_value_only
    mov x0, #0
    bl print_indicator_only
    bl print_status_ok
    b main_loop

imprimir_no_action:
    ldr x1, =msg_action_no_action
    mov x2, len_action_no_action
    bl print_string
    ldr x1, =msg_target_none
    mov x2, len_target_none
    bl print_string
    ldr x1, =msg_risk_low
    mov x2, len_risk_low
    bl print_string
    ldr x1, =msg_reason_manual
    mov x2, len_reason_manual
    bl print_string
    mov x0, #0
    bl print_value_only
    mov x0, #0
    bl print_indicator_only
    bl print_status_ok
    b main_loop

// imprime "VALUE=" seguido del numero
print_value_only:
    stp x29, x30, [sp, #-16]!
    mov x19, x0
    mov x0, #1
    ldr x1, =msg_label_value
    mov x2, len_label_value
    mov x8, #64
    svc #0
    mov x0, x19
    bl print_uint
    ldp x29, x30, [sp], #16
    ret

// imprime "INDICATOR=" seguido del numero
print_indicator_only:
    stp x29, x30, [sp, #-16]!
    mov x19, x0
    mov x0, #1
    ldr x1, =msg_label_indicator
    mov x2, len_label_indicator
    mov x8, #64
    svc #0
    mov x0, x19
    bl print_uint
    ldp x29, x30, [sp], #16
    ret

print_status_ok:
    mov x0, #1
    ldr x1, =msg_status_ok
    mov x2, len_status_ok
    mov x8, #64
    svc #0
    ret

// escribe un string a stdout (x1=ptr, x2=len)
print_string:
    mov x0, #1
    mov x8, #64
    svc #0
    ret

// imprime error y vuelve al ciclo (no termina el programa)
print_error:
    mov x0, #1
    ldr x1, =msg_error_input
    mov x2, len_error_input
    mov x8, #64
    svc #0
    b main_loop

// convierte entero a string y lo imprime con newline
print_uint:
    ldr x1, =num_buffer
    add x1, x1, #31

    mov w2, #0
    strb w2, [x1]

    mov x3, #10
    mov x4, #0

    cmp x0, #0
    bne convert_loop

    // caso especial: el valor es 0
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

end_program:
    mov x0, #0
    mov x8, #93
    svc #0
