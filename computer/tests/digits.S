# Test programs for the simulated computer by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# The two seven-segment digits: writes them with sb, sh and sw, reads them back with lbu, lhu
# and lw (and lb, lh), and prints what it read. digits.expected has what it must print.

#include "computer.h"

	.text
	.globl main
main:
	li s0, DIGIT_RIGHT              # 0xffff0010; the left digit is at 1(s0)

	PRINT "after reset\n"
	lw a0, 0(s0)
	REPORT "  lw  0xffff0010 = ", 8

	PRINT "sb 0x06 at 0xffff0010 (the right digit shows 1)\n"
	li t0, 0x06
	sb t0, 0(s0)
	lbu a0, 0(s0)
	REPORT "  lbu 0xffff0010 = ", 2
	lbu a0, 1(s0)
	REPORT "  lbu 0xffff0011 = ", 2
	lhu a0, 0(s0)
	REPORT "  lhu 0xffff0010 = ", 4
	lw a0, 0(s0)
	REPORT "  lw  0xffff0010 = ", 8

	PRINT "sb 0x5b at 0xffff0011 (the left digit shows 2)\n"
	li t0, 0x5b
	sb t0, 1(s0)
	lbu a0, 0(s0)
	REPORT "  lbu 0xffff0010 = ", 2
	lbu a0, 1(s0)
	REPORT "  lbu 0xffff0011 = ", 2
	lhu a0, 0(s0)
	REPORT "  lhu 0xffff0010 = ", 4
	lw a0, 0(s0)
	REPORT "  lw  0xffff0010 = ", 8

	PRINT "sh 0x4f3f at 0xffff0010 (both digits: 3 and 0)\n"
	li t0, 0x4f3f
	sh t0, 0(s0)
	lbu a0, 0(s0)
	REPORT "  lbu 0xffff0010 = ", 2
	lbu a0, 1(s0)
	REPORT "  lbu 0xffff0011 = ", 2
	lhu a0, 0(s0)
	REPORT "  lhu 0xffff0010 = ", 4
	lw a0, 0(s0)
	REPORT "  lw  0xffff0010 = ", 8

	PRINT "sw 0xa5c3ff80 at 0xffff0010 (bytes 2 and 3 are not kept)\n"
	li t0, 0xa5c3ff80
	sw t0, 0(s0)
	lbu a0, 0(s0)
	REPORT "  lbu 0xffff0010 = ", 2
	lbu a0, 1(s0)
	REPORT "  lbu 0xffff0011 = ", 2
	lbu a0, 2(s0)
	REPORT "  lbu 0xffff0012 = ", 2
	lbu a0, 3(s0)
	REPORT "  lbu 0xffff0013 = ", 2
	lhu a0, 0(s0)
	REPORT "  lhu 0xffff0010 = ", 4
	lhu a0, 2(s0)
	REPORT "  lhu 0xffff0012 = ", 4
	lw a0, 0(s0)
	REPORT "  lw  0xffff0010 = ", 8
	lb a0, 1(s0)
	REPORT "  lb  0xffff0011 = ", 8
	lh a0, 0(s0)
	REPORT "  lh  0xffff0010 = ", 8

	PRINT "sb 0x77 at 0xffff0012 and 0xffff0013, sh 0x7777 at 0xffff0012 (no digit there)\n"
	li t0, 0x7777
	sb t0, 2(s0)
	sb t0, 3(s0)
	sh t0, 2(s0)
	lw a0, 0(s0)
	REPORT "  lw  0xffff0010 = ", 8

	PRINT "sb 0x6d at 0xffff0010 (the left digit keeps its value)\n"
	li t0, 0x6d
	sb t0, 0(s0)
	lw a0, 0(s0)
	REPORT "  lw  0xffff0010 = ", 8

	PRINT "sw 0 at 0x00100010 and 0xffff0014, sb 0 at 0xffff000f (other addresses)\n"
	li t0, 0x00100010
	sw zero, 0(t0)
	sw zero, 4(s0)
	sb zero, -1(s0)
	lw a0, 0(s0)
	REPORT "  lw  0xffff0010 = ", 8
	lw a0, 4(s0)
	REPORT "  lw  0xffff0014 = ", 8

	PRINT "sh 0x7d07 at 0xffff0010 (the digits show 6 and 7)\n"
	li t0, 0x7d07
	sh t0, 0(s0)
	lw a0, 0(s0)
	REPORT "  lw  0xffff0010 = ", 8
	PRINT "done\n"
halt:
	j halt
