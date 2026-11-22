	.data

sum: 	.word 0      # variable to keep the result

	.text
_start:
        li t1,1
        li t2,2
        add s0,t2,t1  # s0 = 1+2 = 3
        la t0,sum     # load address of variable sum in memory to t0
        sw s0,0(t0)   # store word from s0 into memory at the address 0+t0
halt:
        j halt        # loop forever
