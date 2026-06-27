.global _start

.extern utils_parse_i64
.extern utils_validate_range
.extern utils_validate_column
.extern utils_read_int_column
.extern utils_count_lines
.include "sqrt.s"
.include "utils/print_uint.s"

.equ MAX_VALUES, 100

.data
lbl_calc: .ascii "CALC=LINEAR_REGRESSION\n"; len_calc = . - lbl_calc // calcula su longitud exacta en bytes
lbl_col: .ascii "COLUMN="; len_col = . - lbl_col    
lbl_ws: .ascii "WINDOW_START="; len_ws = . - lbl_ws
lbl_we: .ascii "WINDOW_END="; len_we = . - lbl_we
lbl_cnt: .ascii "COUNT="; len_cnt = . - lbl_cnt
lbl_slope: .ascii "SLOPE_X100="; len_slope = . - lbl_slope
lbl_trend: .ascii "TREND="; len_trend = . - lbl_trend
lbl_ok: .ascii "STATUS=OK\n"; len_ok = . - lbl_ok
newline: .ascii "\n"
minus_sign: .ascii "-"