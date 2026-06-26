.global derivada_local

.section .text

derivada_local:
	stp  x29, x30, [sp, #-16]!
	mov  x29, sp
	stp  x19, x20, [sp, #-16]!
	stp  x21, x22, [sp, #-16]!
	stp  x23, x24, [sp, #-16]!

	mov  x19, x0              // base del arreglo
	mov  x20, x1              // N

	// Validacion: se necesitan al menos 5 datos
	cmp  x20, #5
	b.lt dl_error

	// Resultado provisional mientras se implementa el algoritmo
	mov  x0, #0
	b    dl_fin

dl_error:
	mov  x0, #-1

dl_fin:
	ldp  x23, x24, [sp], #16
	ldp  x21, x22, [sp], #16
	ldp  x19, x20, [sp], #16
	ldp  x29, x30, [sp], #16
	ret
