.extern utils_open_csv
.extern utils_read_int_column
.extern utils_close_csv
.extern utils_write_result
.extern utils_i64_to_str
.extern utils_exit

.equ MAX_VALUES, 100

// ---- rodata ----
.section .rodata
.align 3

out_path:	.asciz "results/resultado_tendencia.txt"

lbl_module:	.asciz "MODULE=ADVANCED_TREND\n"
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
nl:		.asciz "\n"
minus_sign:	.asciz "-"

// ---- bss ----
.section .bss
.align 3

values_buf:    .skip 8 * MAX_VALUES
out_buf:       .skip 512

// ---- text ----
.section .text
.global _start

// _start — punto de entrada
// Flujo:
//   1. Abrir CSV y leer ventana dinamica de datos
//   2. Analizar cambios (incrementos, decrementos, rachas)
//   3. Determinar tendencia (UP / DOWN / STABLE)
//   4. Construir y escribir archivo de salida
//
// Registros de larga vida:
//   x19 = fd               x20 = INCREMENTS
//   x21 = DECREMENTS       x22 = MAX_UP_STREAK
//   x23 = MAX_DOWN_STREAK  x24 = ACCUM_DIFF (con signo)
//   x25 = ptr string TREND x26 = N (valores leidos)
_start:
	bl   utils_open_csv
	mov  x19, x0

	// Leer columna configurada con ventana dinamica
	mov  x0, x19
	mov  x1, #1
	adr  x2, values_buf
	mov  x3, #1              // linea inicial
	mov  x4, #MAX_VALUES     // linea final (lee hasta lo que haya)
	bl   utils_read_int_column
	mov  x26, x0             // x26 = N valores leidos

	cmp  x26, #2
	b.lt error_exit           // minimo 2 datos para calcular pares

	mov  x0, x19
	bl   utils_close_csv

	// Contar incrementos/decrementos con rachas
	adr  x0, values_buf
	mov  x1, x26
	bl   contar_cambios
	// x20=INCREMENTS  x21=DECREMENTS  x22=MAX_UP  x23=MAX_DOWN

	// Calcular ACCUM_DIFF y determinar tendencia
	mov  x0, x20
	mov  x1, x21
	bl   calcular_tendencia
	mov  x24, x0
	mov  x25, x1

	// ---- Construir salida en out_buf ----
	adr  x9, out_buf

	// MODULE=ADVANCED_TREND
	adr  x0, lbl_module
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

	// TOTAL_VALUES=<N>
	adr  x0, lbl_total
	mov  x1, x9
	bl   copy_str
	mov  x9, x0
	mov  x0, x26
	mov  x1, x9
	bl   utils_i64_to_str
	mov  x9, x0
	adr  x0, nl
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
	b.ge accum_pos
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

	mov  x0, #0
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

	mov  x20, #0              // incrementos
	mov  x21, #0              // decrementos
	mov  x22, #0              // mejor racha subida
	mov  x23, #0              // mejor racha bajada
	mov  x14, #0              // racha actual subida
	mov  x15, #0              // racha actual bajada

	mov  x9,  x0              // base del arreglo
	sub  x13, x1, #1          // pares a procesar = N - 1
	mov  x10, #0              // indice i

	ldr  x11, [x9]            // primer valor

cc_loop:
	cmp  x10, x13
	b.ge cc_done

	add  x10, x10, #1
	lsl  x16, x10, #3
	ldr  x12, [x9, x16]      // valor[i]

	cmp  x12, x11
	b.gt cc_sube
	b.lt cc_baja

	// estable: cortar ambas rachas
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
