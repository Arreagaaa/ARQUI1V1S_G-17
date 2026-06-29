.data
.align 3

// umbrales
.equ GAS_CRITICAL, 120
.equ GAS_WARNING, 90
.equ GAS_AMP_ALTA, 35
.equ SOIL_BAJO, 358
.equ SOIL_SATURATED, 204
.equ LUZ_BAJA, 665
.equ TEMP_ALTA, 30
.equ TEMP_WARN, 25
.equ FLAG_ALARM_ON,      1
.equ FLAG_GAS_WARNING,   2
.equ FLAG_RIEGO_1_ON,    4
.equ FLAG_LIGHT_ON,      8
.equ FLAG_FAN_ON,        16
.equ FLAG_BLOQUEADO,     32
.equ FLAG_LED_YELLOW,    64
.equ FLAG_LED_GREEN,     128
.equ FLAG_RIEGO_2_ON,    512
.equ FLAG_NO_ACTION,     256
.equ INPUT_BUF_SIZE, 64
.equ NUM_BUF_SIZE, 32

msg_action_alarm_on: .ascii "ACTION=ALARM_ON\n";    len_action_alarm_on = . - msg_action_alarm_on
msg_action_gas_warning: .ascii "ACTION=GAS_WARNING\n";len_action_gas_warning = . - msg_action_gas_warning
msg_action_fan_on: .ascii "ACTION=FAN_ON\n";        len_action_fan_on = . - msg_action_fan_on
msg_action_riego1_on: .ascii "ACTION=RIEGO_1_ON\n"; len_action_riego1_on = . - msg_action_riego1_on
msg_action_riego2_on: .ascii "ACTION=RIEGO_2_ON\n"; len_action_riego2_on = . - msg_action_riego2_on
msg_action_light_on: .ascii "ACTION=LIGHT_ON\n";    len_action_light_on = . - msg_action_light_on
msg_action_led_green: .ascii "ACTION=LED_GREEN\n";  len_action_led_green = . - msg_action_led_green
msg_action_led_yellow: .ascii "ACTION=LED_YELLOW\n";len_action_led_yellow = . - msg_action_led_yellow
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
msg_reason_gas_warning: .ascii "REASON=GAS_MODERATE\n";        len_reason_gas_warning = . - msg_reason_gas_warning
msg_reason_soil: .ascii "REASON=SOIL_LOW_AND_DESCENDING\n";    len_reason_soil = . - msg_reason_soil
msg_reason_soil_saturated: .ascii "REASON=SOIL_SATURATED\n";    len_reason_soil_saturated = . - msg_reason_soil_saturated
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

.extern utils_parse_i64

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
    ble end_program

main_loop_proceed:

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
    mov x14, x0  // gas amplitud

    ldr x0, =hum_array
    ldr x1, =hum_count
    bl calcular_amplitud
    mov x17, x0 // hum amplitud

    // evaluar TODAS las condiciones activas como bitmask
    // x28 = bitmask de flags, x16 = prioridad mas alta (1-9)
    mov x28, #0
    mov x16, #0
    // valores por defecto: NO_ACTION
    ldr x5, =msg_action_no_action
    mov x6, len_action_no_action
    ldr x7, =msg_target_none
    mov x9, len_target_none
    ldr x11, =msg_reason_manual
    mov x12, len_reason_manual
    mov x13, #0
    // modo manual: solo NO_ACTION
    cmp x15, #0
    bne check_mode

    // prioridad 1: gas critico (>92) -> ALARM_ON
    cmp x20, #GAS_CRITICAL
    ble check_gas_amp
    b set_flag_alarm
check_gas_amp:
    // o amplitud reciente de gas elevada (>GAS_AMP_ALTA)
    cmp x14, #GAS_AMP_ALTA
    ble check_gas_warn
    b set_flag_alarm
check_gas_warn:
    // prioridad 2: gas medio (>66) -> GAS_WARNING
    cmp x20, #GAS_WARNING
    ble done_gas
    b set_flag_gas_warning

set_flag_alarm:
    orr x28, x28, #FLAG_ALARM_ON
    cmp x16, #0
    bne done_gas
    mov x16, #1
    ldr x5, =msg_action_alarm_on
    mov x6, len_action_alarm_on
    ldr x7, =msg_target_gas
    mov x9, len_target_gas
    ldr x11, =msg_reason_gas
    mov x12, len_reason_gas
    mov x13, x20
    b done_gas

set_flag_gas_warning:
    orr x28, x28, #FLAG_GAS_WARNING
    cmp x16, #0
    bne done_gas
    mov x16, #2
    ldr x5, =msg_action_gas_warning
    mov x6, len_action_gas_warning
    ldr x7, =msg_target_gas
    mov x9, len_target_gas
    ldr x11, =msg_reason_gas_warning
    mov x12, len_reason_gas_warning
    mov x13, x20

done_gas:
    // prioridad 2: suelo 1 seco y ascendiendo
    // si esta saturado, bloquear riego
    cmp x21, #SOIL_SATURATED
    bge check_soil1_dry
    b set_flag_bloqueado

check_soil1_dry:
    cmp x21, #SOIL_BAJO
    ble check_soil2
    b set_flag_riego1

set_flag_bloqueado:
    orr x28, x28, #FLAG_BLOQUEADO
    cmp x16, #0
    bne check_soil2
    mov x16, #10
    ldr x5, =msg_action_no_action
    mov x6, len_action_no_action
    ldr x7, =msg_target_soil1
    mov x9, len_target_soil1
    ldr x11, =msg_reason_soil_saturated
    mov x12, len_reason_soil_saturated
    mov x13, x21
    b check_soil2

set_flag_riego1:
    orr x28, x28, #FLAG_RIEGO_1_ON
    cmp x16, #0
    bne check_soil2
    mov x16, #3
    ldr x5, =msg_action_riego1_on
    mov x6, len_action_riego1_on
    ldr x7, =msg_target_soil1
    mov x9, len_target_soil1
    ldr x11, =msg_reason_soil
    mov x12, len_reason_soil
    mov x13, x21

    // prioridad 3: suelo 2 seco y tendencia descendente -> RIEGO_2_ON
check_soil2:
    cmp x22, #SOIL_BAJO
    ble check_luz
    cmp x26, #0
    bge check_luz
    b set_flag_riego2

set_flag_riego2:
    orr x28, x28, #FLAG_RIEGO_2_ON
    cmp x16, #0
    bne check_luz
    mov x16, #4
    ldr x5, =msg_action_riego2_on
    mov x6, len_action_riego2_on
    ldr x7, =msg_target_soil2
    mov x9, len_target_soil2
    ldr x11, =msg_reason_soil
    mov x12, len_reason_soil
    mov x13, x22

check_luz:
    cmp x23, #LUZ_BAJA
    bge check_temp
    orr x28, x28, #FLAG_LIGHT_ON
    cmp x16, #0
    bne check_temp
    mov x16, #5
    ldr x5, =msg_action_light_on
    mov x6, len_action_light_on
    ldr x7, =msg_target_luz
    mov x9, len_target_luz
    ldr x11, =msg_reason_light
    mov x12, len_reason_light
    mov x13, x23

check_temp:
    cmp x24, #TEMP_ALTA
    ble check_mode
    cmp x19, #0
    ble check_mode
    b set_flag_fan

set_flag_fan:
    orr x28, x28, #FLAG_FAN_ON
    cmp x16, #0
    bne check_mode
    mov x16, #6
    ldr x5, =msg_action_fan_on
    mov x6, len_action_fan_on
    ldr x7, =msg_target_temp
    mov x9, len_target_temp
    ldr x11, =msg_reason_temp
    mov x12, len_reason_temp
    mov x13, x24

check_mode:
    cmp x15, #0
    bne set_flag_noact
    cmp x24, #TEMP_WARN
    ble check_soil_warn_flg
    cmp x19, #0
    ble check_soil_warn_flg
    ldr x7, =msg_target_temp
    mov x9, len_target_temp
    ldr x11, =msg_reason_temp
    mov x12, len_reason_temp
    mov x13, x24
    b set_flag_yellow

check_soil_warn_flg:
    cmp x21, #SOIL_BAJO
    ble check_luz_warn
    cmp x25, #0
    bge check_luz_warn
    ldr x7, =msg_target_soil1
    mov x9, len_target_soil1
    ldr x11, =msg_reason_soil
    mov x12, len_reason_soil
    mov x13, x21
    b set_flag_yellow

check_luz_warn:
    cmp x23, #LUZ_BAJA
    bge set_flag_green
    cmp x27, #0
    bge set_flag_green
    ldr x7, =msg_target_luz
    mov x9, len_target_luz
    ldr x11, =msg_reason_light
    mov x12, len_reason_light
    mov x13, x23
    b set_flag_yellow

set_flag_green:
    orr x28, x28, #FLAG_LED_GREEN
    cmp x16, #0
    bne output_combined
    mov x16, #8
    ldr x5, =msg_action_led_green
    mov x6, len_action_led_green
    ldr x7, =msg_target_general
    mov x9, len_target_general
    ldr x11, =msg_reason_normal
    mov x12, len_reason_normal
    mov x13, #0
    b output_combined

set_flag_yellow:
    orr x28, x28, #FLAG_LED_YELLOW
    cmp x16, #0
    bne output_combined
    mov x16, #7
    ldr x5, =msg_action_led_yellow
    mov x6, len_action_led_yellow
    b output_combined

set_flag_noact:
    orr x28, x28, #FLAG_NO_ACTION
    cmp x16, #0
    bne output_combined
    mov x16, #9
    ldr x5, =msg_action_no_action
    mov x6, len_action_no_action
    ldr x7, =msg_target_none
    mov x9, len_target_none
    ldr x11, =msg_reason_manual
    mov x12, len_reason_manual
    mov x13, #0

output_combined:
    // x28 = flags bitmask, x16 = highest priority index
    // x5/x6 = action msg, x7/x9 = target msg, x11/x12 = reason msg, x13 = indicator
    stp x29, x30, [sp, #-16]!
    stp x27, x28, [sp, #-16]!

    // ACTION=<name>
    mov x0, #1
    mov x1, x5
    mov x2, x6
    mov x8, #64
    svc #0

    // TARGET=<target>
    mov x0, #1
    mov x1, x7
    mov x2, x9
    mov x8, #64
    svc #0

    // RISK segun prioridad mas alta
    cmp x16, #1
    beq risk_crit
    cmp x16, #2
    beq risk_high
    cmp x16, #3
    beq risk_med
    cmp x16, #7
    beq risk_low
    cmp x16, #8
    beq risk_low
    cmp x16, #9
    beq risk_low
    cmp x16, #10
    beq risk_low
    b risk_med
risk_crit:
    ldr x1, =msg_risk_critical
    mov x2, len_risk_critical
    b print_risk
risk_high:
    ldr x1, =msg_risk_high
    mov x2, len_risk_high
    b print_risk
risk_low:
    ldr x1, =msg_risk_low
    mov x2, len_risk_low
    b print_risk
risk_med:
    ldr x1, =msg_risk_medium
    mov x2, len_risk_medium
print_risk:
    mov x0, #1
    mov x8, #64
    svc #0

    // REASON=<reason>
    mov x0, #1
    mov x1, x11
    mov x2, x12
    mov x8, #64
    svc #0

    // VALUE=<bitmask>
    mov x0, #1
    ldr x1, =msg_label_value
    mov x2, len_label_value
    mov x8, #64
    svc #0
    mov x0, x28
    bl print_uint

    // INDICATOR=<indicator>
    mov x0, #1
    ldr x1, =msg_label_indicator
    mov x2, len_label_indicator
    mov x8, #64
    svc #0
    mov x0, x13
    bl print_uint

    // STATUS=OK
    mov x0, #1
    ldr x1, =msg_status_ok
    mov x2, len_status_ok
    mov x8, #64
    svc #0

    ldp x27, x28, [sp], #16
    ldp x29, x30, [sp], #16
    b main_loop

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
