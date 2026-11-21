# Test programs for the simulated computer by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# The start of every test program, and what they print with

#include "computer.h"

	.section .init
	.globl _start
_start:
	la sp, __stack_init
	call main
halt:
	j halt

	.text

# putc: prints the character in a0. It changes t0.
	.globl putc
putc:
	li t0, TTY
	sw a0, 0(t0)
	ret

# puts: prints the zero-terminated string at the address in a0. It changes a0, t0 and t1.
	.globl puts
puts:
	li t0, TTY
1:	lbu t1, 0(a0)
	beqz t1, 2f
	sw t1, 0(t0)
	addi a0, a0, 1
	j 1b
2:	ret

# puthex: prints the value of a0 as a1 hexadecimal digits (1 to 8). It changes t0 to t3.
	.globl puthex
puthex:
	li t0, TTY
	slli t1, a1, 2
1:	addi t1, t1, -4
	srl t2, a0, t1
	andi t2, t2, 15
	li t3, 10
	blt t2, t3, 2f
	addi t2, t2, 'a' - '0' - 10
2:	addi t2, t2, '0'
	sw t2, 0(t0)
	bnez t1, 1b
	ret
