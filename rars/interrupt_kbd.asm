	# Template for the program with intererupts
	
	.text
main:
	# enabling interrupt processing

	la t0,isr
	csrw t0,mtvec    # writing address of ISR to utvec
	
	li t0,0x111
	csrw t0,mie      # enabling IRQs from all sources
	
	li t0,1
	csrw t0,mstatus  # enabling general interrupt processing
	
	li t0, 0xffff0000
	li t1, 0x2       # writing 2 into RCR turns on interrupt mode
	sw t1, 0(t0)	 # The keyboard will now raise an IRQ when
			

	
        # main program
	
        li s0, 0xffff0010
loop:
        li t0, 0x3f
        sb t0, 0(s0)
        li t0, 0x06
        sb t0, 0(s0)
        li t0, 0x5b
        sb t0, 0(s0)
        li t0, 0x4f
        sb t0, 0(s0)
        j loop       

	
isr:
	# interrupt service routine 
	
	csrw t0,mscratch # put value of t0 temporaroly into mscratch
	la t0,frame	 # load address of the frame into t0
	sw t1,4(t0)	 # save double-word value of t1 into 4(frame)
	sw s0,8(t0)      # save double-word value of s0 into 8(frame)
	sw s1,12(t0)     # save double-word value of s1 into 12(frame)
	csrr t1,mscratch # get the original value of t0 from mscratch
	sw t1,0(t0)      # and save it to 0(frame)
	csrr t1,mepc     # get the original value of mepc
	sw t1,16(t0)     # and save it to 16(frame)
	
	# rest of ISR code (uses t0,t1,s0,s1)
	
	li s0,0xffff0004 # address of keyboard RDR 
	li s1,0xffff000c # address of display TDR
	lw t0,0(s0)      # load character code from RDR
	sw t0,0(s1)      # send it to TDR 
			
	la t0,frame	 # load address of the frame into t0
	lw t1,16(t0)     # load original value of mepc from 16(frame)
	csrw t1,mepc     # and write it into uepc
	lw t1,0(t0)      # load original value of t0 from 0(frame)
	csrw t1,mscratch # and write it temporarily into mscratch
	lw s1,12(t0)     # load original value of s1 from 12(frame)
	lw s0,8(t0)      # load original value of s0 from 8(frame)
	lw t1,4(t0)      # load original value of t1 from 4(frame)
	csrr t0,mscratch # get the original value from mscratch into t0

	mret		 # return to main program to the address in mepc
	
	.data
frame:
	.word 0 # 0(frame)  location for storing t0
	.word 0	# 4(frame)  location for storing t1
	.word 0 # 8(frame)  location for storing s0
	.word 0 # 12(frame) location for storing s1
	.word 0	# 16(frame) location for storing mepc
	
	

	
	
	
