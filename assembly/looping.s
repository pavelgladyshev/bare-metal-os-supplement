# This example prints the message (Hello)
# onto the terminal

	
	.data				# data to be printed (the linker puts .data in ROM on this computer)
hi:	.asciz "Hello"		# .asciz automatically adds an extra 0 byte after the text
	
	.text
	la t0, hi			# load address of the message into t0
	li t2, 0xffff000c	# load address of the terminal's transmitter data register (TDR) into t2
loop:
	lb t1,0(t0)			# load the ASCII code of the next character of the message into t1
	beq t1,zero, quit	# if the code is 0, exit the loop
	sw t1,0(t2)			# print the character: store its code into the TDR
	addi t0,t0,1		# advance t0 to the next character in the message
	j loop				# go to the start of the loop

quit:					# the whole message has been printed
halt:	j halt			# keep looping forever after the program finishes
	 
