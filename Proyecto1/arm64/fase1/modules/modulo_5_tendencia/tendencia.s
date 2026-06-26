.global _start

.extern utils_parse_i64
.extern utils_validate_range
.extern utils_validate_column
.extern utils_read_int_column
.extern utils_i64_to_str
.extern utils_write_result
.extern utils_exit

.equ MAX_VALUES, 100

.data
out_path:	.asciz "results/resultado_tendencia.txt"

lbl_module:	.asciz "MODULE=ADVANCED_TREND\n"
lbl_col:	.asciz "COLUMN="
lbl_ws:		.asciz "WINDOW_START="
lbl_we:		.asciz "WINDOW_END="
lbl_cnt:	.asciz "COUNT="
lbl_total:	.asciz "TOTAL_VALUES="
lbl_incr:	.asciz "INCREMENTS="
lbl_decr:	.asciz "DECREMENTS="
lbl_maxup:	.asciz "MAX_UP_STREAK="
lbl_maxdn:	.asciz "MAX_DOWN_STREAK="
lbl_accum:	.asciz "ACCUM_DIFF="
lbl_trend:	.asciz "TREND="
str_up:		.asciz "UP"
str_down:	.asciz "DOWN"
str_stable:	.asciz "STABLE"
lbl_ok:		.asciz "STATUS=OK\n"
nl:		.asciz "\n"
minus_sign:	.asciz "-"

msg_err_argc: .ascii "STATUS=ERROR\nERROR=INVALID_ARGS\nDETAIL=EXPECTED_4_ARGS\n"
len_err_argc = . - msg_err_argc
msg_err_rng: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=START_END_INVALID\n"
len_err_rng = . - msg_err_rng
msg_err_col: .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_MUST_BE_1_TO_6\n"
len_err_col = . - msg_err_col
msg_err_opn: .ascii "STATUS=ERROR\nERROR=FILE_NOT_FOUND\nDETAIL=COULD_NOT_OPEN_FILE\n"
len_err_opn = . - msg_err_opn

.bss
values_buf:    .skip 8 * MAX_VALUES
out_buf:       .skip 512

.text

// Registros de larga vida en _start:
//   x19 = path csv / fd      x20 = INCREMENTS
//   x21 = DECREMENTS         x22 = MAX_UP_STREAK
//   x23 = MAX_DOWN_STREAK    x24 = ACCUM_DIFF (con signo)
//   x25 = ptr string TREND   x26 = N (valores leidos)
//   x27 = columna            x28 = fila inicio
//   [sp, #0] = fila fin (se guarda en stack)
_start:
	ldr  x0, [sp]
	cmp  x0, #5
	blt  error_argc

	ldr  x19, [sp, #16]

	ldr  x0, [sp, #24]
	bl   utils_parse_i64
	mov  x28, x0

	ldr  x0, [sp, #32]
	bl   utils_parse_i64
	sub  sp, sp, #16
	str  x0, [sp]              // guardar fila fin en stack

	ldr  x0, [sp, #56]        // argv[4] = columna (sp+16+40)
	bl   utils_parse_i64
	mov  x27, x0

	// validar rango
	mov  x0, x28
	ldr  x1, [sp]
	bl   utils_validate_range
	cbnz x0, error_range

	// validar columna
	mov  x0, x27
	bl   utils_validate_column
	cbnz x0, error_column

	// abrir csv con openat
	mov  x0, #-100
	mov  x1, x19
	mov  x2, #0
	mov  x3, #0
	mov  x8, #56
	svc  #0
	cmp  x0, #0
	blt  error_open

	mov  x19, x0

	// leer columna del csv
	mov  x0, x19
	mov  x1, x27
	ldr  x2, =values_buf
	mov  x3, x28
	ldr  x4, [sp]
	bl   utils_read_int_column
	mov  x26, x0

	// cerrar csv
	mov  x0, x19
	mov  x8, #57
	svc  #0

	cmp  x26, #2
	b.lt error_exit

	// Contar incrementos/decrementos con rachas
	ldr  x0, =values_buf
	mov  x1, x26
	bl   contar_cambios

	// Calcular ACCUM_DIFF y determinar tendencia
	mov  x0, x20
	mov  x1, x21
	bl   calcular_tendencia
	mov  x24, x0
	mov  x25, x1

	// ---- Construir salida en out_buf ----
	ldr  x9, =out_buf

	ldr  x0, =lbl_module
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// COLUMN=
	ldr  x0, =lbl_col
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x27
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	ldr  x0, =nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// WINDOW_START=
	ldr  x0, =lbl_ws
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x28
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	ldr  x0, =nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// WINDOW_END=
	ldr  x0, =lbl_we
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	ldr  x0, [sp]
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	ldr  x0, =nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// COUNT=
	ldr  x0, =lbl_cnt
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x26
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	ldr  x0, =nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// TOTAL_VALUES=
	ldr  x0, =lbl_total
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x26
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	ldr  x0, =nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// INCREMENTS=
	ldr  x0, =lbl_incr
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x20
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	ldr  x0, =nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// DECREMENTS=
	ldr  x0, =lbl_decr
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x21
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	ldr  x0, =nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// MAX_UP_STREAK=
	ldr  x0, =lbl_maxup
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x22
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	ldr  x0, =nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// MAX_DOWN_STREAK=
	ldr  x0, =lbl_maxdn
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x23
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	ldr  x0, =nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// ACCUM_DIFF= (puede ser negativo)
	ldr  x0, =lbl_accum
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	cmp  x24, #0
	b.ge accum_pos
	ldr  x0, =minus_sign
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	neg  x0, x24
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	b    accum_nl
accum_pos:
	mov  x0, x24
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
accum_nl:
	ldr  x0, =nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// TREND=
	ldr  x0, =lbl_trend
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x25
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	ldr  x0, =nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// STATUS=OK
	ldr  x0, =lbl_ok
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// Escribir archivo de resultados
	ldr  x10, =out_buf
	sub  x2, x9, x10
	ldr  x0, =out_path
	ldr  x1, =out_buf
	bl   utils_write_result

	mov  x0, #0
	bl   utils_exit

// ---- Manejo de errores ----
error_argc:
	mov  x0, #1
	ldr  x1, =msg_err_argc
	mov  x2, len_err_argc
	mov  x8, #64
	svc  #0
	mov  x0, #1
	bl   utils_exit

error_range:
	mov  x0, #1
	ldr  x1, =msg_err_rng
	mov  x2, len_err_rng
	mov  x8, #64
	svc  #0
	mov  x0, #1
	bl   utils_exit

error_column:
	mov  x0, #1
	ldr  x1, =msg_err_col
	mov  x2, len_err_col
	mov  x8, #64
	svc  #0
	mov  x0, #1
	bl   utils_exit

error_open:
	mov  x0, #1
	ldr  x1, =msg_err_opn
	mov  x2, len_err_opn
	mov  x8, #64
	svc  #0
	mov  x0, #1
	bl   utils_exit

error_exit:
	mov  x0, #1
	bl   utils_exit

// contar_cambios — analiza pares consecutivos del arreglo
// Entrada: x0 = base del arreglo, x1 = N (cantidad de datos)
// Salida:  x20 = INCREMENTS, x21 = DECREMENTS
//          x22 = MAX_UP_STREAK, x23 = MAX_DOWN_STREAK
contar_cambios:
	stp  x29, x30, [sp, #-16]!
	mov  x29, sp

	mov  x20, #0
	mov  x21, #0
	mov  x22, #0
	mov  x23, #0
	mov  x14, #0
	mov  x15, #0

	mov  x9,  x0
	sub  x13, x1, #1
	mov  x10, #0

	ldr  x11, [x9]

cc_loop:
	cmp  x10, x13
	b.ge cc_done

	add  x10, x10, #1
	lsl  x16, x10, #3
	ldr  x12, [x9, x16]

	cmp  x12, x11
	b.gt cc_sube
	b.lt cc_baja

	mov  x14, #0
	mov  x15, #0
	b    cc_next

cc_sube:
	add  x20, x20, #1
	add  x14, x14, #1
	mov  x15, #0
	cmp  x14, x22
	b.le cc_next
	mov  x22, x14
	b    cc_next

cc_baja:
	add  x21, x21, #1
	add  x15, x15, #1
	mov  x14, #0
	cmp  x15, x23
	b.le cc_next
	mov  x23, x15

cc_next:
	mov  x11, x12
	b    cc_loop

cc_done:
	ldp  x29, x30, [sp], #16
	ret

// calcular_tendencia — ACCUM_DIFF y etiqueta de tendencia
// Entrada: x0 = INCREMENTS, x1 = DECREMENTS
// Salida:  x0 = ACCUM_DIFF (con signo), x1 = ptr string tendencia
calcular_tendencia:
	stp  x29, x30, [sp, #-16]!
	mov  x29, sp

	sub  x0, x0, x1

	cmp  x0, #0
	b.gt ct_up
	b.lt ct_down
	ldr  x1, =str_stable
	b    ct_fin
ct_up:
	ldr  x1, =str_up
	b    ct_fin
ct_down:
	ldr  x1, =str_down
ct_fin:
	ldp  x29, x30, [sp], #16
	ret

// copy_str — copia ASCIIZ de x0 a x1
// Salida: x0 = siguiente byte libre en destino
copy_str:
	ldrb w2, [x0]
	cbz  w2, cs_done
	strb w2, [x1]
	add  x0, x0, #1
	add  x1, x1, #1
	b    copy_str
cs_done:
	mov  x0, x1
	ret
