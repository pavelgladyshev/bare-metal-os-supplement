# This program takes a number from memory location (in RAM)
# labelled A, then adds 5 to it, and stores the result into 
# memory location (also in RAM) labelled B.

	.bss			# what follows is in RAM: variables, which have no starting values

A:	.space 4		# reserve 32-bit word in the data area (RAM) and label it "A";
                    # it has no value until the program gives it one
                    
B:	.space 4		# reserve another 32-bit word in the data area (RAM)
					# immediately after the preceding word, and label it "B";
					# it gets its value from the program too

	.text
main:
	la   t0,A		# Load Address of the word labelled as A into t0
	li   t1,1		# load the starting value of A, 1, into t1
	sw   t1,0(t0)	# and store it into A
	lw   t1,0(t0)	# load the value stored in that memory word to t1
	addi t1,t1,5	# add 5 to the value in t1
	la   t2,B		# Load Address of the word labelled as B into t2
	sw   t1,0(t2)	# store the 32-bit value from t1 into that memory location
       
halt:	j halt		# keep looping forever: the result, 6, is in B
