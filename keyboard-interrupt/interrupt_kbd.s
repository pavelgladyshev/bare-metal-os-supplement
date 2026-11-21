	# Template for the program with interrupts
	
	.text
main:
	# enabling interrupt processing

	la t0,isr
	csrw mtvec,t0    # writing address of ISR to mtvec
	
	li t0,0x800
	csrw mie,t0      # enabling external IRQs (bit 11 of mie)
	
	li t0,8
	csrw mstatus,t0  # enabling general interrupt processing (bit 3 of mstatus)
	
	li t0, 0xffff0004
	li t1, 0x2       # writing 2 into RCR turns on interrupt mode
	sw t1, 0(t0)	 # The keyboard will now raise an IRQ when
			 # a character is waiting

	
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
	
	csrw mscratch,t0 # put value of t0 temporarily into mscratch
	la t0,frame	 # load address of the frame into t0
	sw t1,4(t0)	 # save value of t1 into 4(frame)
	sw s0,8(t0)      # save value of s0 into 8(frame)
	sw s1,12(t0)     # save value of s1 into 12(frame)
	csrr t1,mscratch # get the original value of t0 from mscratch
	sw t1,0(t0)      # and save it to 0(frame)
	csrr t1,mepc     # get the original value of mepc
	sw t1,16(t0)     # and save it to 16(frame)
	
	# rest of ISR code (uses t0,t1,s0,s1)
	
	li s0,0xffff0008 # address of keyboard RDR 
	li s1,0xffff000c # address of display TDR
	lw t0,0(s0)      # load character code from RDR
	sw t0,0(s1)      # send it to TDR 
			
	la t0,frame	 # load address of the frame into t0
	lw t1,16(t0)     # load original value of mepc from 16(frame)
	csrw mepc,t1     # and write it into mepc
	lw t1,0(t0)      # load original value of t0 from 0(frame)
	csrw mscratch,t1 # and write it temporarily into mscratch
	lw s1,12(t0)     # load original value of s1 from 12(frame)
	lw s0,8(t0)      # load original value of s0 from 8(frame)
	lw t1,4(t0)      # load original value of t1 from 4(frame)
	csrr t0,mscratch # get the original value from mscratch into t0

	mret		 # return to main program to the address in mepc
	
	.section .bss
frame:
	.space 4 # 0(frame)  location for storing t0
	.space 4 # 4(frame)  location for storing t1
	.space 4 # 8(frame)  location for storing s0
	.space 4 # 12(frame) location for storing s1
	.space 4 # 16(frame) location for storing mepc
