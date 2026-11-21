# Test programs for the simulated computer by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# The keyboard interrupt. The main program counts on the two digits; the interrupt handler
# echoes each character typed, and prints mcause the first time. kbdirq.script types the
# characters and kbdirq.expected has what the program must print.
#
#   part 0  the keyboard's interrupt enable (bit 1 of 0xffff0004) is written and read
#   part 1  the enable bit is 0, as after reset, and the CPU's own enables are on: a character
#           waits and no interrupt comes
#   part 2  the program sets the enable bit: the interrupt comes at once, and for each
#           character after it, until a full stop is typed
#   part 3  the enable bit is 0 again: a character waits and no interrupt comes

#include "computer.h"

	.bss
interrupts:	.word 0                 # how many times the handler ran
finished:	.word 0                 # set by the handler when it reads a full stop
mip_before:	.word 0                 # mip in the handler, before it read the character
mip_after:	.word 0                 # and after

	.text
	.globl main
main:
	li s0, KBD_RCR
	li s2, DIGIT_RIGHT

	PRINT "part 0: the interrupt enable bit, with interrupts off in the CPU\n"
	lw a0, 0(s0)
	REPORT "  after reset                 RCR = ", 8
	li t0, RCR_IE
	sb t0, 0(s0)
	lw a0, 0(s0)
	REPORT "  sb 0x02 at 0xffff0004       RCR = ", 8
	lbu a0, 0(s0)
	REPORT "                              lbu = ", 2
	sb zero, 0(s0)
	lw a0, 0(s0)
	REPORT "  sb 0x00 at 0xffff0004       RCR = ", 8
	li t0, RCR_IE
	sh t0, 0(s0)
	lw a0, 0(s0)
	REPORT "  sh 0x0002 at 0xffff0004     RCR = ", 8
	li t0, 0xfffffffd
	sw t0, 0(s0)
	lw a0, 0(s0)
	REPORT "  sw 0xfffffffd at 0xffff0004 RCR = ", 8
	li t0, 0xffffffff
	sw t0, 0(s0)
	lw a0, 0(s0)
	REPORT "  sw 0xffffffff at 0xffff0004 RCR = ", 8
	sw zero, 0(s0)
	li t0, 0xff
	sb t0, 1(s0)
	sb t0, 2(s0)
	sb t0, 3(s0)
	sh t0, 2(s0)
	lw a0, 0(s0)
	REPORT "  sw 0, then sb 0xff at 0xffff0005 to 0xffff0007 and sh at 0xffff0006: RCR = ", 8
	csrr a0, mip
	REPORT "  mip = ", 8

	la t0, handler
	csrw mtvec, t0
	li t0, MIE_MEIE
	csrw mie, t0                    # the machine external interrupt, and no other
	csrsi mstatus, MSTATUS_MIE      # interrupts on in the CPU

	PRINT "part 1: interrupt enable 0, interrupts on in the CPU\n"
	lw a0, 0(s0)
	REPORT "  RCR = ", 8
1:	lw t0, 0(s0)                    # wait for a character
	andi t0, t0, RCR_READY
	beqz t0, 1b
	lw a0, 0(s0)
	REPORT "  a character is waiting: RCR = ", 8
	csrr a0, mip
	REPORT "  mip = ", 8
	la t0, interrupts
	lw a0, 0(t0)
	REPORT "  interrupts = ", 8

	PRINT "part 2: interrupt enable 1\n"
	li t0, RCR_IE
	sw t0, 0(s0)                    # the waiting character interrupts here

	li s3, 0                        # count on the digits until the handler has read a full stop
2:	addi s3, s3, 1
	sh s3, 0(s2)
	la t0, finished
	lw t0, 0(t0)
	beqz t0, 2b

	sw zero, 0(s0)                  # the interrupt enable off again
	PRINT "\n"
	lw a0, 0(s0)
	REPORT "  RCR = ", 8
	la t0, mip_before
	lw a0, 0(t0)
	REPORT "  mip in the handler, before it read the character = ", 8
	la t0, mip_after
	lw a0, 0(t0)
	REPORT "  mip in the handler, after = ", 8
	la t0, interrupts
	lw a0, 0(t0)
	REPORT "  interrupts = ", 8
	lhu t0, 0(s2)                   # the digits hold the count's low 16 bits
	slli t1, s3, 16
	srli t1, t1, 16
	sub a0, t0, t1
	REPORT "  the digits minus the count = ", 8
	snez a0, s3
	REPORT "  the main program counted meanwhile (1 = yes): ", 1

	PRINT "part 3: interrupt enable 0\n"
3:	lw t0, 0(s0)                    # wait for a character
	andi t0, t0, RCR_READY
	beqz t0, 3b
	lw a0, 0(s0)
	REPORT "  a character is waiting: RCR = ", 8
	csrr a0, mip
	REPORT "  mip = ", 8
	la t0, interrupts
	lw a0, 0(t0)
	REPORT "  interrupts = ", 8
	li t0, KBD_RDR
	lw a0, 0(t0)
	REPORT "  the character, read by the main program = ", 2
	lw a0, 0(s0)
	REPORT "  RCR = ", 8
	li t0, KBD_RDR
	lw a0, 0(t0)
	REPORT "  the data register, read again with no character waiting = ", 8
	PRINT "done\n"
halt:
	j halt

# The interrupt handler: reads one character and prints it. It keeps the registers that it and
# the print functions change on the interrupted program's stack.
	.balign 4
handler:
	addi sp, sp, -32
	sw ra, 0(sp)
	sw a0, 4(sp)
	sw a1, 8(sp)
	sw s1, 12(sp)
	sw t0, 16(sp)
	sw t1, 20(sp)
	sw t2, 24(sp)
	sw t3, 28(sp)

	la t0, interrupts
	lw t1, 0(t0)
	addi t1, t1, 1
	sw t1, 0(t0)
	li t2, 1
	bne t1, t2, 1f                  # the first time: print mcause and keep mip
	csrr a0, mcause
	REPORT "  the handler: mcause = ", 8
	csrr t1, mip
	la t0, mip_before
	sw t1, 0(t0)
	li t0, KBD_RDR
	lw a0, 0(t0)                    # reading the character takes the request down
after_read:
	csrr t1, mip
	la t0, mip_after
	sw t1, 0(t0)
	mv s1, a0
	PRINT "  typed: "
	mv a0, s1
	j 2f
1:	li t0, KBD_RDR
	lw a0, 0(t0)
2:	li t0, '.'
	bne a0, t0, 3f
	la t0, finished
	li t1, 1
	sw t1, 0(t0)
3:	call putc

	lw ra, 0(sp)
	lw a0, 4(sp)
	lw a1, 8(sp)
	lw s1, 12(sp)
	lw t0, 16(sp)
	lw t1, 20(sp)
	lw t2, 24(sp)
	lw t3, 28(sp)
	addi sp, sp, 32
	mret
