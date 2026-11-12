# Example software running in Logisim RISC-V Computer System model by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# This is a simple program written in RISC-V assembly language 

	.text            

	la t0, 0xffff000C         # TTY display output MMIO register
	li t1, 'H'
	sw t1, 0(t0)
	li t1, 'i'
	sw t1, 0(t0)
	li t1, '\n'
	sw t1, 0(t0)

halt:
	j halt                    # keep looping forever after program finishes
