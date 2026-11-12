# This example picks the largest of two numbers
# loaded into t0 and t1 and prints it on the console
		
		.text

		li t0,10		# load 10 into t0
		li t1,5			# load 5 into t1
		
		blt t1,t0,l1	# Brach if t1 is Less Than t0, to label l1
						# otherwise continue to the next instruction
		mv t4,t1		# t1 is NOT less than t0, therefore t1 is the max, copy it to t4
		j l2			# Jump to label l2 to print the result

l1:		mv t4,t0		# CPU gets here only if t1 is less than t0
						# therefore, t0 is the max, copy it to t4

l2:		li a7,1			# load syscall number 1 (PrintInt) to a7
		mv a0,t4		# copy t4 to a0 (the number to print)
		ecall			# do syscall
		
		li a7,10		# load syscall number 10 (Exit) to a7
		ecall			# terminate the prorgam
