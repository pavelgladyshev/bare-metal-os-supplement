# Test programs for the simulated computer by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# For a picture of the circuit: lights both digits (4 on the left, 2 on the right, with the
# right digit's decimal point: between them the two patterns light every segment), prints a line,
# and then echoes what is typed from the keyboard's interrupt handler.

#include "computer.h"

	.text
	.globl main
main:
	li t0, DIGIT_RIGHT
	li t1, 0x66                     # segments b, c, f and g: 4
	sb t1, 1(t0)                    # the left digit
	li t1, 0xdb                     # segments a, b, d, e and g: 2, and the decimal point
	sb t1, 0(t0)                    # the right digit
	PRINT "The digits show 42.\nType here: "
	la t0, handler
	csrw mtvec, t0
	li t0, MIE_MEIE
	csrw mie, t0
	li t0, KBD_RCR
	li t1, RCR_IE
	sw t1, 0(t0)
	csrsi mstatus, MSTATUS_MIE
halt:
	j halt

	.balign 4
handler:
	li t0, KBD_RDR
	lw a0, 0(t0)
	li t0, TTY
	sw a0, 0(t0)
	mret
