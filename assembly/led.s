# This example displays digit 1 on the right-most
# 7-segment LED display of the computer
#
# Run it with make PROG=led gui: the digit appears on the
# right-hand display in Logisim's window.

		.text
main:
		li t0, 0xffff0010	# load address of 7-segment LED display into t0
		li t1, 0x06			# load the bit pattern of digit 1 into t1
		sb t1, 0(t0)		# store byte with the pattern into
		                    # 7-segment LED display control register
              
halt:	j halt			# keep looping forever after the program finishes
