// =============================================================================
// tendencia.s — Módulo 5: Tendencia acumulada avanzada
// Integrante 5
//
// Lee la columna TEMP del archivo ../lecturas.csv (30 datos reales),
// calcula diferencias consecutivas, las suma, cuenta incrementos/decrements,
// encuentra rachas máximas y clasifica la tendencia final.
//
// Fórmulas (enunciado ACYE1 §10.5):
//   DIF_i      = X_i - X_(i-1)        (para i = 1..29)
//   INCREMENTOS = #{i : DIF_i > 0}
//   DECREMENTS = #{i : DIF_i < 0}
//   MAX_UP_STREAK = racha más larga de DIF_i > 0 consecutivos
//   MAX_DOWN_STREAK = racha más larga de DIF_i < 0 consecutivos
//   DIF_ACUM   = Σ DIF_i
//   TREND = UP si DIF_ACUM > 0, DOWN si < 0, STABLE si == 0
//
// Formato exacto de salida:
//   MODULE=ADVANCED_TREND
//   TOTAL_VALUES=30
//   INCREMENTS=18
//   DECREMENTS=10
//   MAX_UP_STREAK=5
//   MAX_DOWN_STREAK=3
//   ACCUM_DIFF=7
//   TREND=UP
//
// TODO: Integrante 5
//   - Recorrer 29 diferencias consecutivas
//   - Llevar contadores y rachas
//   - Acumular DIF_ACUM
//   - Clasificar tendencia final
// =============================================================================

.section .data
msg_module:        .ascii "MODULE=ADVANCED_TREND\n"
msg_module_len = . - msg_module
msg_total:         .ascii "TOTAL_VALUES=30\n"
msg_total_len = . - msg_total
msg_inc:           .ascii "INCREMENTS="
msg_inc_len = . - msg_inc
msg_dec:           .ascii "DECREMENTS="
msg_dec_len = . - msg_dec
msg_up:            .ascii "MAX_UP_STREAK="
msg_up_len = . - msg_up
msg_down:          .ascii "MAX_DOWN_STREAK="
msg_down_len = . - msg_down
msg_accum:         .ascii "ACCUM_DIFF="
msg_accum_len = . - msg_accum
msg_trend_up:      .ascii "TREND=UP\n"
msg_trend_up_len = . - msg_trend_up
msg_trend_down:    .ascii "TREND=DOWN\n"
msg_trend_down_len = . - msg_trend_down
msg_trend_stable:  .ascii "TREND=STABLE\n"
msg_trend_stable_len = . - msg_trend_stable
msg_nl:            .ascii "\n"
msg_nl_len = . - msg_nl

.equ N_VALUES, 30
.equ N_DIFFS,  29      // 30 - 1 diferencias

.section .bss
.lcomm values,     8 * N_VALUES
.lcomm result_buf, 256

.section .text
.global _start

_start:
    // TODO:
    //   1. utils_open_csv + utils_read_int_column(1, values)
    //   2. Para i = 1..29:
    //        diff = values[i] - values[i-1]
    //        acc += diff
    //        si diff > 0: inc++; curr_up++; curr_down=0; max_up=max(max_up,curr_up)
    //        si diff < 0: dec++; curr_down++; curr_up=0;   max_down=max(max_down,curr_down)
    //        si diff == 0: curr_up=0; curr_down=0
    //   3. trend = UP/DOWN/STABLE según acc
    //   4. utils_write_result
    //   5. utils_exit(0)

    mov x0, #0
    bl utils_exit

// Subrutinas propias:
compute_tendency: ret
