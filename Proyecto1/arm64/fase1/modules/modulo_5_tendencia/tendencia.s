.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

.equ N_VALUES,    30
.equ N_PAIRS,     29

// ---- rodata ----
.section .rodata
.align 3

out_path:	.asciz "results/resultado_tendencia.txt"

lbl_module:	.asciz "MODULE=ADVANCED_TREND\n"
lbl_total:	.asciz "TOTAL_VALUES=30\n"
lbl_incr:	.asciz "INCREMENTS="
lbl_decr:	.asciz "DECREMENTS="
lbl_maxup:	.asciz "MAX_UP_STREAK="
lbl_maxdn:	.asciz "MAX_DOWN_STREAK="
lbl_accum:	.asciz "ACCUM_DIFF="
lbl_trend:	.asciz "TREND="
str_up:		.asciz "UP"
str_down:	.asciz "DOWN"
str_stable:	.asciz "STABLE"
nl:		.asciz "\n"
minus_sign:	.asciz "-"

// ---- bss ----
.section .bss
.align 3

values_buf:    .skip 8 * N_VALUES              // arreglo de 30 enteros (8 bytes c/u)
out_buf:       .skip 512                       // buffer de salida (8 líneas)

// ---- text ----
.section .text
.global _start

// -----------------------------------------------------------------------------
// _start — punto de entrada principal
// -----------------------------------------------------------------------------
// Flujo:
//   1. Abrir  lecturas.csv             → x19 = fd
//   2. Leer   30 valores de col TEMP   → values_buf[30]
//   3. Cerrar archivo de entrada
//   4. Llamar compute_tendency         → x20..x24 = resultados
//   5. Construir archivo de salida     → out_buf
//   6. Escribir resultado con utils_write_result
//   7. exit(0)
//
// Registros de larga vida (callee-saved):
//   x19 = fd (entrada)
//   x20 = INCREMENTS   (después de compute_tendency)
//   x21 = DECREMENTS   (después de compute_tendency)
//   x22 = MAX_UP_STREAK (después de compute_tendency)
//   x23 = MAX_DOWN_STREAK (después de compute_tendency)
//   x24 = ACCUM_DIFF   (después de compute_tendency, con signo)
//   x25 = longitud del buffer de salida
// -----------------------------------------------------------------------------
_start:
	// Abrir lecturas.csv
	bl   utils_open_csv
	mov  x19, x0

	// Leer columna 5 (GAS) de linea 1 a 30
	mov  x0, x19
	mov  x1, #5
	ldr  x2, =values_buf
	mov  x3, #1
	mov  x4, #N_VALUES
	bl   utils_read_int_column
	// utils_read_int_column devuelve cuantos valores leyo
	cmp  x0, #N_VALUES
	beq  tend_read_ok
	b    error_exit
tend_read_ok:

	// Cerrar archivo
	mov  x0, x19
	bl   utils_close_csv

	// Contar incrementos y decrementos con rachas
	adr  x0, values_buf
	bl   contar_cambios
	// x20=INCREMENTS  x21=DECREMENTS  x22=MAX_UP  x23=MAX_DOWN

	// Calcular ACCUM_DIFF y determinar TREND
	mov  x0, x20
	mov  x1, x21
	bl   calcular_tendencia
	mov  x24, x0               // ACCUM_DIFF
	mov  x25, x1               // puntero a string TREND

	// Construir salida en out_buf
	adr  x9, out_buf

	// MODULE=ADVANCED_TREND
	adr  x0, lbl_module
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// TOTAL_VALUES=30
	adr  x0, lbl_total
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// INCREMENTS=<valor>
	adr  x0, lbl_incr
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x20
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	adr  x0, nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// DECREMENTS=<valor>
	adr  x0, lbl_decr
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x21
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	adr  x0, nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// MAX_UP_STREAK=<valor>
	adr  x0, lbl_maxup
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x22
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	adr  x0, nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// MAX_DOWN_STREAK=<valor>
	adr  x0, lbl_maxdn
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x23
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	adr  x0, nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// ACCUM_DIFF=<valor> (puede ser negativo)
	adr  x0, lbl_accum
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	cmp  x24, #0
	bge  accum_pos
	b    accum_neg
accum_neg:
	adr  x0, minus_sign
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
	adr  x0, nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// TREND=<UP|DOWN|STABLE>
	adr  x0, lbl_trend
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x25
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	adr  x0, nl
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// Escribir archivo de resultados
	adr  x10, out_buf
	sub  x2, x9, x10
	adr  x0, out_path
	adr  x1, out_buf
	bl   utils_write_result

	// Salir
	mov  x0, #0
	bl   utils_exit

error_exit:
	mov  x0, #1
	bl   utils_exit

// contar_cambios — analiza pares consecutivos del arreglo
// Entrada: x0 = dirección base del buffer de valores
// Salida:  x20 = INCREMENTS, x21 = DECREMENTS
//          x22 = MAX_UP_STREAK, x23 = MAX_DOWN_STREAK
contar_cambios:
	stp  x29, x30, [sp, #-16]!
	mov  x29, sp

	mov  x20, #0                // incrementos
	mov  x21, #0                // decrementos
	mov  x22, #0                // racha maxima subida
	mov  x23, #0                // racha maxima bajada
	mov  x14, #0                // racha actual subida
	mov  x15, #0                // racha actual bajada

	mov  x9, x0                 // base del arreglo
	mov  x10, #0                // indice i

	ldr  x11, [x9]              // primer valor

cc_loop:
	cmp  x10, #N_PAIRS
	bge  cc_done
	b    cc_body
cc_body:

	add  x10, x10, #1
	lsl  x16, x10, #3
	ldr  x12, [x9, x16]        // valor[i+1]

	cmp  x12, x11
	ble  tend_check_down
	b    cc_sube
tend_check_down:
	cmp  x12, x11
	bge  cc_next
	b    cc_baja

	// estable: reiniciar rachas
	mov  x14, #0
	mov  x15, #0
	b    cc_next

cc_sube:
	add  x20, x20, #1
	add  x14, x14, #1
	mov  x15, #0
	cmp  x14, x22
	ble  cc_next
	b    tend_new_max_up
tend_new_max_up:
	mov  x22, x14
	b    cc_next

cc_baja:
	add  x21, x21, #1
	add  x15, x15, #1
	mov  x14, #0
	cmp  x15, x23
	ble  cc_next
	b    tend_new_max_dn
tend_new_max_dn:
	mov  x23, x15

cc_next:
	mov  x11, x12
	b    cc_loop

cc_done:
	ldp  x29, x30, [sp], #16
	ret

// calcular_tendencia — ACCUM_DIFF y dirección de tendencia
// Entrada: x0 = INCREMENTS, x1 = DECREMENTS
// Salida:  x0 = ACCUM_DIFF (con signo), x1 = ptr string tendencia
calcular_tendencia:
	stp  x29, x30, [sp, #-16]!
	mov  x29, sp

	sub  x0, x0, x1             // ACCUM_DIFF = inc - dec

	cmp  x0, #0
	ble  ct_check_down
	b    ct_up
ct_check_down:
	cmp  x0, #0
	bge  ct_stable
	b    ct_down
ct_stable:
	adr  x1, str_stable
	b    ct_fin
ct_up:
	adr  x1, str_up
	b    ct_fin
ct_down:
	adr  x1, str_down
ct_fin:
	ldp  x29, x30, [sp], #16
	ret

// copy_str — copia string ASCIIZ de x0 a x1
// Salida: x0 = puntero al byte siguiente libre

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