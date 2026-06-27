.data
.align 3

// umbrales
.equ GAS_ALTO, 300
.equ GAS_AMP_ALTA, 50
.equ SOIL_BAJO, 300
.equ LUZ_BAJA, 500
.equ TEMP_ALTA, 30
.equ INPUT_BUF_SIZE, 64
.equ NUM_BUF_SIZE, 32

msg_action_alarm_on: .ascii "ACTION=ALARM_ON\n";    len_action_alarm_on = . - msg_action_alarm_on
msg_action_fan_on: .ascii "ACTION=FAN_ON\n";        len_action_fan_on = . - msg_action_fan_on
msg_action_riego1_on: .ascii "ACTION=RIEGO_1_ON\n"; len_action_riego1_on = . - msg_action_riego1_on
msg_action_riego2_on: .ascii "ACTION=RIEGO_2_ON\n"; len_action_riego2_on = . - msg_action_riego2_on
msg_action_light_on: .ascii "ACTION=LIGHT_ON\n";    len_action_light_on = . - msg_action_light_on
msg_action_led_green: .ascii "ACTION=LED_GREEN\n";  len_action_led_green = . - msg_action_led_green
msg_action_led_yellow: .ascii "ACTION=LED_YELLOW\n";len_action_led_yellow = . - msg_action_led_yellow
msg_action_led_red: .ascii "ACTION=LED_RED\n";      len_action_led_red = . - msg_action_led_red
msg_action_no_action: .ascii "ACTION=NO_ACTION\n";  len_action_no_action = . - msg_action_no_action

msg_target_gas: .ascii "TARGET=GAS_SENSOR\n";     len_target_gas = . - msg_target_gas
msg_target_soil1: .ascii "TARGET=SOIL1\n";        len_target_soil1 = . - msg_target_soil1
msg_target_soil2: .ascii "TARGET=SOIL2\n";        len_target_soil2 = . - msg_target_soil2
msg_target_luz: .ascii "TARGET=LUZ\n";            len_target_luz = . - msg_target_luz
msg_target_temp: .ascii "TARGET=TEMPERATURE\n";   len_target_temp = . - msg_target_temp
msg_target_general: .ascii "TARGET=GENERAL\n";    len_target_general = . - msg_target_general
msg_target_none: .ascii "TARGET=NONE\n";          len_target_none = . - msg_target_none

msg_risk_critical: .ascii "RISK=CRITICAL\n";      len_risk_critical = . - msg_risk_critical
msg_risk_high: .ascii "RISK=HIGH\n";              len_risk_high = . - msg_risk_high
msg_risk_medium: .ascii "RISK=MEDIUM\n";          len_risk_medium = . - msg_risk_medium
msg_risk_low: .ascii "RISK=LOW\n";                len_risk_low = . - msg_risk_low

msg_reason_gas: .ascii "REASON=GAS_HIGH_OR_AMPLITUDE_HIGH\n";  len_reason_gas = . - msg_reason_gas
msg_reason_soil: .ascii "REASON=SOIL_LOW_AND_DESCENDING\n";    len_reason_soil = . - msg_reason_soil
msg_reason_light: .ascii "REASON=LIGHT_LOW_AND_DESCENDING\n";  len_reason_light = . - msg_reason_light
msg_reason_temp: .ascii "REASON=TEMP_HIGH_AND_ASCENDING\n";    len_reason_temp = . - msg_reason_temp
msg_reason_normal: .ascii "REASON=NORMAL_CONDITIONS\n";        len_reason_normal = . - msg_reason_normal
msg_reason_manual: .ascii "REASON=MANUAL_MODE\n";              len_reason_manual = . - msg_reason_manual

msg_label_value: .ascii "VALUE=";                 len_label_value = . - msg_label_value
msg_label_indicator: .ascii "INDICATOR=";         len_label_indicator = . - msg_label_indicator
msg_status_ok: .ascii "STATUS=OK\n";              len_status_ok = . - msg_status_ok
msg_error_input: .ascii "STATUS=ERROR\nERROR=INVALID_INPUT\nDETAIL=EXPECTED_7_FIELDS\n"
    len_error_input = . - msg_error_input
newline: .ascii "\n"
minus_sign: .ascii "-"

// arrays circulares de 5 posiciones cada uno
temp_array:
    .quad 0, 0, 0, 0, 0
temp_count:
    .quad 0
hum_array:
    .quad 0, 0, 0, 0, 0
hum_count:
    .quad 0
soil1_array:
    .quad 0, 0, 0, 0, 0
soil1_count:
    .quad 0
soil2_array:
    .quad 0, 0, 0, 0, 0
soil2_count:
    .quad 0
luz_array:
    .quad 0, 0, 0, 0, 0
luz_count:
    .quad 0
gas_array:
    .quad 0, 0, 0, 0, 0
gas_count:
    .quad 0

.bss
.align 3
input_buffer: .skip INPUT_BUF_SIZE
num_buffer: .skip NUM_BUF_SIZE

.text
.global _start

.include "utils/atoi.s"
.include "utils/array.s"
.include "utils/promedio.s"
.include "utils/tendencia.s"
.include "utils/amplitud.s"
.include "utils/print_uint.s"

_start:

main_loop:
    // leer entrada desde stdin
    mov x0, #0
    ldr x1, =input_buffer
    mov x2, #INPUT_BUF_SIZE
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

    // parsear 7 campos separados por coma
    mov x5, #10
    bl atoi_csv
    cbz x7, print_error
    mov x9, x10 // temp

    bl atoi_csv
    cbz x7, print_error
    mov x18, x10 // humedad

    bl atoi_csv
    cbz x7, print_error
    mov x11, x10 // suelo 1

    bl atoi_csv
    cbz x7, print_error
    mov x12, x10 // suelo 2

    bl atoi_csv
    cbz x7, print_error
    mov x13, x10 // luz

    bl atoi_csv
    cbz x7, print_error
    mov x14, x10 // gas

    bl atoi_csv
    cbz x7, print_error
    mov x15, x10 // modo

    // guardar cada sensor en su buffer circular
    mov x0, x9
    ldr x1, =temp_count
    ldr x3, =temp_array
    bl guardar_dato

    mov x0, x18
    ldr x1, =hum_count
    ldr x3, =hum_array
    bl guardar_dato

    mov x0, x11
    ldr x1, =soil1_count
    ldr x3, =soil1_array
    bl guardar_dato

    mov x0, x12
    ldr x1, =soil2_count
    ldr x3, =soil2_array
    bl guardar_dato

    mov x0, x13
    ldr x1, =luz_count
    ldr x3, =luz_array
    bl guardar_dato

    mov x0, x14
    ldr x1, =gas_count
    ldr x3, =gas_array
    bl guardar_dato

    // calcular promedio por sensor
    ldr x0, =gas_array
    ldr x1, =gas_count
    bl calcular_promedio
    mov x20, x0 // gas promedio

    ldr x0, =soil1_array
    ldr x1, =soil1_count
    bl calcular_promedio
    mov x21, x0 // soil1 promedio

    ldr x0, =soil2_array
    ldr x1, =soil2_count
    bl calcular_promedio
    mov x22, x0 // soil2 promedio

    ldr x0, =luz_array
    ldr x1, =luz_count
    bl calcular_promedio
    mov x23, x0 // luz promedio

    ldr x0, =temp_array
    ldr x1, =temp_count
    bl calcular_promedio
    mov x24, x0 // temp promedio

    ldr x0, =hum_array
    ldr x1, =hum_count
    bl calcular_promedio
    mov x16, x0 // hum promedio

    // calcular tendencias
    ldr x0, =temp_array
    ldr x1, =temp_count
    bl calcular_tendencia
    mov x19, x0 // temp tendencia

    ldr x0, =soil1_array
    ldr x1, =soil1_count
    bl calcular_tendencia
    mov x25, x0 // soil1 tendencia

    ldr x0, =soil2_array
    ldr x1, =soil2_count
    bl calcular_tendencia
    mov x26, x0 // soil2 tendencia

    ldr x0, =luz_array
    ldr x1, =luz_count
    bl calcular_tendencia
    mov x27, x0 // luz tendencia

    // calcular amplitudes
    ldr x0, =gas_array
    ldr x1, =gas_count
    bl calcular_amplitud
    mov x28, x0 // gas amplitud

    ldr x0, =hum_array
    ldr x1, =hum_count
    bl calcular_amplitud
    mov x17, x0 // hum amplitud

    // cadena de decisiones por prioridad
    // prioridad 1: gas alto o amplitud de gas alta
    cmp x20, #GAS_ALTO
    bgt output_gas_alarm

    cmp x28, #GAS_AMP_ALTA
    bgt output_gas_alarm

    // prioridad 2: suelo 1 seco y ascendiendo (pull-up: seco=raw alto)
    cmp x21, #SOIL_BAJO
    bgt check_soil2_low
    b check_soil2

check_soil2_low:
    cmp x25, #0
    bgt output_riego1

check_soil2:
    // prioridad 3: suelo 2 seco y ascendiendo (pull-up: seco=raw alto)
    cmp x22, #SOIL_BAJO
    bgt check_soil2_low2
    b check_luz

check_soil2_low2:
    cmp x26, #0
    bgt output_riego2

check_luz:
    // prioridad 4: luz baja y descendiendo
    cmp x23, #LUZ_BAJA
    blt check_luz_low
    b check_temp

check_luz_low:
    cmp x27, #0
    blt output_light_on

check_temp:
    // prioridad 5: temperatura alta y ascendiendo
    cmp x24, #TEMP_ALTA
    bge check_temp_high
    b check_mode

check_temp_high:
    cmp x19, #0
    bgt output_fan_on

check_mode:
    // prioridad 6 o 7 segun modo
    cmp x15, #0
    bne output_no_action
    // warning: tendencia descendente en suelo o luz -> LED_YELLOW
    cmp x25, #0
    blt output_led_yellow
    cmp x26, #0
    blt output_led_yellow
    cmp x27, #0
    blt output_led_yellow
    // prioridad 6: estado normal -> LED_GREEN
    b output_led_green

output_gas_alarm:
    mov x0, x20; mov x1, x28
    ldr x19, =msg_action_alarm_on; mov x20, len_action_alarm_on
    ldr x21, =msg_target_gas;      mov x22, len_target_gas
    ldr x23, =msg_risk_critical;   mov x24, len_risk_critical
    ldr x25, =msg_reason_gas;      mov x26, len_reason_gas
    bl output_action
    b main_loop

output_riego1:
    mov x0, x21; mov x1, x25
    ldr x19, =msg_action_riego1_on; mov x20, len_action_riego1_on
    ldr x21, =msg_target_soil1;     mov x22, len_target_soil1
    ldr x23, =msg_risk_medium;      mov x24, len_risk_medium
    ldr x25, =msg_reason_soil;      mov x26, len_reason_soil
    bl output_action
    b main_loop

output_riego2:
    mov x0, x22; mov x1, x26
    ldr x19, =msg_action_riego2_on; mov x20, len_action_riego2_on
    ldr x21, =msg_target_soil2;     mov x22, len_target_soil2
    ldr x23, =msg_risk_medium;      mov x24, len_risk_medium
    ldr x25, =msg_reason_soil;      mov x26, len_reason_soil
    bl output_action
    b main_loop

output_light_on:
    mov x0, x23; mov x1, x27
    ldr x19, =msg_action_light_on; mov x20, len_action_light_on
    ldr x21, =msg_target_luz;      mov x22, len_target_luz
    ldr x23, =msg_risk_medium;     mov x24, len_risk_medium
    ldr x25, =msg_reason_light;    mov x26, len_reason_light
    bl output_action
    b main_loop

output_fan_on:
    mov x0, x24; mov x1, x19
    ldr x19, =msg_action_fan_on; mov x20, len_action_fan_on
    ldr x21, =msg_target_temp;   mov x22, len_target_temp
    ldr x23, =msg_risk_medium;   mov x24, len_risk_medium
    ldr x25, =msg_reason_temp;   mov x26, len_reason_temp
    bl output_action
    b main_loop

output_led_green:
    mov x0, #0; mov x1, #0
    ldr x19, =msg_action_led_green; mov x20, len_action_led_green
    ldr x21, =msg_target_general;   mov x22, len_target_general
    ldr x23, =msg_risk_low;         mov x24, len_risk_low
    ldr x25, =msg_reason_normal;    mov x26, len_reason_normal
    bl output_action
    b main_loop

output_led_yellow:
    mov x0, #0; mov x1, #0
    ldr x19, =msg_action_led_yellow;  mov x20, len_action_led_yellow
    ldr x21, =msg_target_general;     mov x22, len_target_general
    ldr x23, =msg_risk_medium;        mov x24, len_risk_medium
    ldr x25, =msg_reason_normal;      mov x26, len_reason_normal
    bl output_action
    b main_loop

output_led_red:
    mov x0, #0; mov x1, #0
    ldr x19, =msg_action_led_red;  mov x20, len_action_led_red
    ldr x21, =msg_target_general;  mov x22, len_target_general
    ldr x23, =msg_risk_high;       mov x24, len_risk_high
    ldr x25, =msg_reason_normal;   mov x26, len_reason_normal
    bl output_action
    b main_loop

output_no_action:
    mov x0, #0; mov x1, #0
    ldr x19, =msg_action_no_action; mov x20, len_action_no_action
    ldr x21, =msg_target_none;      mov x22, len_target_none
    ldr x23, =msg_risk_low;         mov x24, len_risk_low
    ldr x25, =msg_reason_manual;    mov x26, len_reason_manual
    bl output_action
    b main_loop

// output_action: x0=val, x1=ind; args via x19-x26
output_action:
    stp x29, x30, [sp, #-16]!
    stp x27, x28, [sp, #-16]!
    mov x27, x0
    mov x28, x1
    mov x0, #1
    mov x1, x19; mov x2, x20; mov x8, #64; svc #0
    mov x0, #1
    mov x1, x21; mov x2, x22; mov x8, #64; svc #0
    mov x0, #1
    mov x1, x23; mov x2, x24; mov x8, #64; svc #0
    mov x0, #1
    mov x1, x25; mov x2, x26; mov x8, #64; svc #0
    mov x0, #1
    ldr x1, =msg_label_value;       mov x2, len_label_value;       mov x8, #64; svc #0
    mov x0, x27; bl print_uint
    mov x0, #1
    ldr x1, =msg_label_indicator;   mov x2, len_label_indicator;   mov x8, #64; svc #0
    mov x0, x28; bl print_uint
    mov x0, #1
    ldr x1, =msg_status_ok;         mov x2, len_status_ok;         mov x8, #64; svc #0
    ldp x27, x28, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// imprime error y continua
print_error:
    mov x0, #1
    ldr x1, =msg_error_input
    mov x2, len_error_input
    mov x8, #64 // write
    svc #0
    b main_loop

end_program:
    mov x0, #0
    mov x8, #93 // exit
    svc #0
