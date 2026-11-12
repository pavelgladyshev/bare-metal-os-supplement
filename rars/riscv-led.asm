# This example displays digit 1 on the right-most
# 7-segment LED display of Digital Lab Sim tool in RARS
#
# N.B. Do not forget to click "Connect to Program" button
# in the tool window BEFORE running the program!

		.text
main:
		li t0, 0xffff0010	# load address of 7-segment LED display into t0
		li t1, 0x06			# load the bit pattern of digit 1 into t1
		sb t1, 0(t0)		# store byte with the pattern into
		                    # 7-segment LED display control register
              
		li a7, 10			# invoke system call No.10
		ecall				# to terminate the program
