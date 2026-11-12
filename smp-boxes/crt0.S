# Example software running in Logisim RISC-V Computer System model by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# This is a rudimentary C run-time initialisation file (crt0.S) required for C programs to work 

	.section .init            # linker configuration file places .init section at the very start of ROM area before .text

	.extern __stack_init      # address of the initial top of C call stack (calculated externally by linker)

	.globl _start
_start:                       # this is where CPU starts executing instructions after reset / power-on
	la t1,__stack_init
	csrr t0,mhartid           # get hart ID
	slli t0,t0,12             # multiply hart ID by 4096, which is the size of stack area for a hart
	sub t1,t1,t0              # step back from __stack_init by hardID*4096 memory locations, 
	                          #   to ensure that stack areas of different harts do not overlap 
	mv sp,t1                  # initialise stack pointer
	li a0,0                   # populate optional main() parameters with dummy values (just in case)
	li a1,0
	li a2,0
	jal main                  # call C main() function
exit:
	j exit                    # keep looping forever after main() returns
