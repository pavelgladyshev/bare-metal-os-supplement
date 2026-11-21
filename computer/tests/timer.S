# Test programs for the simulated computer by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# The Timer and the state after reset: prints the Timer's registers as they are when the
# simulation starts, then sets mtimecmp 2000 clock cycles ahead with the three stores of the
# RISC-V specification and waits for the timer interrupt, whose handler prints mcause and mip.
# timer.expected has what the program must print.

#include "computer.h"

#define MTIMECMP 0x02004000     /* low word; the high word is 4 above */
#define MTIME    0x0200bff8     /* low word; the high word is 4 above */
#define MIE_MTIE 0x80           /* mie and mip bit 7: machine timer interrupt */

	.bss
interrupts:	.word 0                 # how many times the handler ran

	.text
	.globl main
main:
	li s0, MTIMECMP
	li s2, MTIME

	PRINT "after reset\n"
	lw a0, 4(s0)
	REPORT "  mtimecmp, high word = ", 8
	lw a0, 0(s0)
	REPORT "  mtimecmp, low word  = ", 8
	lw a0, 4(s2)
	REPORT "  mtime, high word    = ", 8
	lw t0, 0(s2)
	li t1, 100000
	sltu a0, t0, t1
	REPORT "  mtime, low word, is below 100000 (1 = yes): ", 1
	lw t0, 0(s2)
	lw t1, 0(s2)
	sltu a0, t0, t1
	REPORT "  mtime counts on (1 = yes): ", 1
	csrr a0, mip
	REPORT "  mip = ", 8
	csrr a0, mie
	REPORT "  mie = ", 8
	csrr a0, mstatus
	REPORT "  mstatus = ", 8
	li t0, 0x00180000
	lw a0, 0(t0)
	REPORT "  the word of the RAM at 0x00180000 = ", 8

	PRINT "the timer interrupt\n"
	la t0, handler
	csrw mtvec, t0
	lw t0, 0(s2)                    # mtime (its high word is 0 for the next 2^32 cycles)
	addi t0, t0, 2000
	li t1, -1
	sw t1, 0(s0)                    # mtimecmp: all ones to the low word,
	sw zero, 4(s0)                  # the new high word,
	sw t0, 0(s0)                    # the new low word
	lw a0, 4(s0)
	REPORT "  mtimecmp, high word = ", 8
	csrr a0, mip
	REPORT "  mip before the time has come = ", 8
	li t0, MIE_MTIE
	csrw mie, t0
	csrsi mstatus, MSTATUS_MIE
1:	la t0, interrupts               # wait for the interrupt
	lw t0, 0(t0)
	beqz t0, 1b
	csrr a0, mip
	REPORT "  mip after the handler = ", 8
	la t0, interrupts
	lw a0, 0(t0)
	REPORT "  interrupts = ", 8
	PRINT "done\n"
halt:
	j halt

# The interrupt handler: prints mcause and mip, and moves mtimecmp out of reach, which takes
# the request down. It keeps the registers that it and the print functions change.
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

	csrr a0, mcause
	REPORT "  the handler: mcause = ", 8
	csrr a0, mip
	REPORT "  the handler: mip = ", 8
	li t0, MTIMECMP
	li t1, -1
	sw t1, 0(t0)
	sw t1, 4(t0)
	la t0, interrupts
	lw t1, 0(t0)
	addi t1, t1, 1
	sw t1, 0(t0)

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
