# Example software running in SMP RISC-V Simulated in QEMU. Author: Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# This is a very simple program. It prints ID of the CPU hart that runs it.
# Try running it with different values of CPUS variable specified in the Makefile !
#

	.section .init            # linker configuration file places .init section at the very start of QEMU RAM 
	.globl _start
_start:                       # this is where CPU hart jumps after reset / power-on ROM
	csrr t0, mhartid          # read hart ID to t0
	addi t0, t0, '0'          # convert it to an ASCII digit
	li   t1, 0x10000000       # load console TDR address to t1
	sb   t0, 0(t1)            # write ID digit to console
	li   t0, '\n'             # load newline character to t0
    sb   t0, 0(t1)            # write it to console
halt:
	j halt                    # keep looping forever 
