# This example prints the message (Hello)
# onto system console

	
	.data				# data to be printed (goes to the data area, usually RAM)
hi:	.asciz "Hello"		# .asciz automatically adds an extra 0 byte after the text
	
	.text
	la t0, hi			# load address of the message into t0
loop:
	lb t1,0(t0)			# load the ASCII code of the next character of the message into t1
	beq t1,zero, quit	# if the code is 0, exit the loop
	mv a0,t1			# copy the code into a0 (required parameter of the system call)
	li a7,11			# load the number of the system call (PrintChar, 11) into a7
	ecall				# invoke system call to print the character
	addi t0,t0,1		# advance t0 to the next character in the message
	j loop				# go to the start of the loop

quit:	li a7,10		# load the number of the system call (Exit, 10) into a7
	ecall 				# terminate this program
	 
