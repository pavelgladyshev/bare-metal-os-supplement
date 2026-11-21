# Test programs for the simulated computer by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# The device registers of computer.circ that the tests use (../README.md has them all)

#define KBD_RCR     0xffff0004      /* keyboard, receiver control: bit 0 a character is waiting,
                                       bit 1 interrupt enable */
#define KBD_RDR     0xffff0008      /* keyboard, receiver data: the character; reading removes it */
#define TTY         0xffff000c      /* terminal, transmitter data */
#define DIGIT_RIGHT 0xffff0010      /* right seven-segment digit, one byte */
#define DIGIT_LEFT  0xffff0011      /* left seven-segment digit, one byte */

#define RCR_READY   1
#define RCR_IE      2

#define MSTATUS_MIE 0x8             /* mstatus bit 3: machine interrupts enabled */
#define MIE_MEIE    0x800           /* mie and mip bit 11: machine external interrupt */

# REPORT "text", n prints the text, then the value of a0 as n hexadecimal digits, then a new line.
# It changes a0, a1, s1, the t registers and ra.
.macro REPORT text, ndigits
	.section .rodata
9:	.asciz "\text"
	.text
	mv s1, a0
	la a0, 9b
	call puts
	mv a0, s1
	li a1, \ndigits
	call puthex
	li a0, '\n'
	call putc
.endm

# PRINT "text" prints the text. It changes a0, the t registers and ra.
.macro PRINT text
	.section .rodata
9:	.asciz "\text"
	.text
	la a0, 9b
	call puts
.endm
