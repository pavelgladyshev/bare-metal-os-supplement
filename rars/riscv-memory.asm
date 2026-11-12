# This program takes a number from memory location (in RAM)
# labeled A, then adds 5 to it, and stores the result into 
# memory location (also in RAM) labelled B.

	.data

A:	.word 1			# reserve 32-bit word in the data area (RAM), 
                    # label it "A", and initialize to the value 1
                    
B:	.word 2			# reserve another 32-bit word in the data area (RAM)
					# immediately after the preceding word, label it "B",
					# and set its initial value to 2

	.text
main:
	la   t0,A		# Load Address of the .word labeled as A into t0
	lw   t1,0(t0)	# load the value stored in that memory word to t1
	addi t1,t1,5	# add 5 to the value in t1
	la   t2,B		# Load Address of the .word labeled as B into t2
	sw   t1,0(t2)	# store the 32-bit value from t1 into that memory location
       
	li a7,10		# Load system call number 10 (Exit) to a7
	ecall			# perform syscall to terminate this program	
