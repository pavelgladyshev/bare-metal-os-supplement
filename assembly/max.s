# This example picks the largest of two numbers
# loaded into t0 and t1 and leaves it in t4
		
		.text

		li t0,10		# load 10 into t0
		li t1,5			# load 5 into t1
		
		blt t1,t0,l1	# Branch if t1 is Less Than t0, to label l1
						# otherwise continue to the next instruction
		mv t4,t1		# t1 is NOT less than t0, therefore t1 is the max, copy it to t4
		j l2			# Jump to label l2, the end of the program

l1:		mv t4,t0		# CPU gets here only if t1 is less than t0
						# therefore, t0 is the max, copy it to t4

l2:					# the result, the larger number, is in t4
halt:	j halt		# keep looping forever after the program finishes
