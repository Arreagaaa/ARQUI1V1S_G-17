/ modulo_4_integral_error.s — Integrante 3 — Grupo 17
.equ MAX_VALUES, 1000

.extern utils_open_csv
.extern utils_read_int_column
.extern utils_parse_i64
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

.section .rodata
.align 3
out_path:      .asciz "results/resultado_integral.txt"
lbl_calc:      .asciz "CALC=ERROR_INTEGRAL\n"
lbl_col:       .asciz "COLUMN="
lbl_win_start: .asciz "WINDOW_START="
lbl_win_end:   .asciz "WINDOW_END="
lbl_count:     .asciz "COUNT="
lbl_ideal:     .asciz "IDEAL="
lbl_err_int:   .asciz "ERROR_INTEGRAL="
lbl_status:    .asciz "STATUS=OK\n"
nl:            .asciz "\n"

.section .bss
.align 3
values_buf:  .skip 8 * MAX_VALUES
out_buf:     .skip 512

.section .text
.global _start