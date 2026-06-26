.global _start

.extern utils_parse_i64
.extern utils_validate_range
.extern utils_validate_column
.extern utils_read_int_column
.extern utils_i64_to_str
.extern utils_write_result
.extern utils_print_string
.extern utils_print_newline
.extern utils_exit

.equ MAX_VALUES, 100
.equ MIN_DATOS, 5
.equ VENTANA_REG, 5

.data
out_path:	.asciz "results/resultado_derivada_local.txt"

lbl_module:	.asciz "MODULE=LOCAL_DERIVATIVE\n"
lbl_col:	.asciz "COLUMN="
lbl_ws:		.asciz "WINDOW_START="
lbl_we:		.asciz "WINDOW_END="
lbl_cnt:	.asciz "COUNT="
lbl_ok:		.asciz "STATUS=OK\n"
nl:		.asciz "\n"

msg_err_argc: .ascii "STATUS=ERROR\nERROR=INVALID_ARGS\nDETAIL=EXPECTED_4_ARGS\n"
len_err_argc = . - msg_err_argc
msg_err_rng: .ascii "STATUS=ERROR\nERROR=INVALID_RANGE\nDETAIL=START_END_INVALID\n"
len_err_rng = . - msg_err_rng
msg_err_col: .ascii "STATUS=ERROR\nERROR=INVALID_COLUMN\nDETAIL=COLUMN_MUST_BE_1_TO_6\n"
len_err_col = . - msg_err_col
msg_err_opn: .ascii "STATUS=ERROR\nERROR=FILE_NOT_FOUND\nDETAIL=COULD_NOT_OPEN_FILE\n"
len_err_opn = . - msg_err_opn
msg_err_few: .ascii "STATUS=ERROR\nERROR=INSUFFICIENT_DATA\nDETAIL=NEED_AT_LEAST_5_VALUES\n"
len_err_few = . - msg_err_few

.bss
values_buf:    .skip 8 * MAX_VALUES
out_buf:       .skip 512

.text

// Registros de larga vida:
//   x19 = fd              x26 = N (valores leidos)
//   x27 = columna         x28 = fila inicio
//   [sp, #0] = fila fin
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
	str  x0, [sp]

	ldr  x0, [sp, #56]
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

	// validar minimo de 5 datos para regresion local
	cmp  x26, #MIN_DATOS
	b.lt error_few_data

	// Ciclo externo: recorrer ventana deslizante de regresion 
	// Para cada posicion i desde 0 hasta N-VENTANA_REG se aplica regresion lineal local sobre los VENTANA_REG valores consecutivos
	// El resultado es la pendiente (derivada discreta) en cada punto.

	ldr  x0, =values_buf
	mov  x1, x26
	mov  x10, #0                     // i = 0 (indice de inicio de ventana)
	sub  x13, x26, #VENTANA_REG      // limite = N - VENTANA_REG

dl_ext_loop:
	cmp  x10, x13
	b.gt dl_ext_done

	// x10 = posicion actual de la ventana
	// base del sub-arreglo: values_buf + i*8
	lsl  x11, x10, #3
	ldr  x12, =values_buf
	add  x12, x12, x11               // x12 = ptr al inicio de la sub-ventana

	// TODO: Implementar formula de regresion local de Fase 2 en el proximo commit
	// Aqui se calculara la pendiente por minimos cuadrados sobre VENTANA_REG puntos:pendiente = (n*sum_xy - sum_x*sum_y) / (n*sum_x2 - sum_x^2)
	// donde x = {0,1,...,VENTANA_REG-1} e y = valores del sub-arreglo.

	add  x10, x10, #1
	b    dl_ext_loop

dl_ext_done:

	// Construir salida basica 
	ldr  x9, =out_buf

	ldr  x0, =lbl_module
	mov  x1, x9
	bl   copy_str
	mov  x9, x0

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

// Manejo de errores 
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

error_few_data:
	mov  x0, #1
	ldr  x1, =msg_err_few
	mov  x2, len_err_few
	mov  x8, #64
	svc  #0
	mov  x0, #1
	bl   utils_exit

// copy_str, copia ASCIIZ de x0 a x1
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
