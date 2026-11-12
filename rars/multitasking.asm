# To run this program you need to open Digital Lab Sim tool
# and connect it to simulation by clicking "Connect to Program"
                
        .text
main:
	# set-up trap handler
 	la s0,trap_handler
 	csrw s0,mtvec       # set mtvec = address of the handler
 	
 	# enable processing of interrup requests from timer
 	#li s1,0x100  
 	li s1,0x10      
 	csrw s1,mie         # set mie = 0x10 

 	# enable interrupts in CPU
        csrsi mstatus,1    # set interrupt enable bit in mstatus (0) 
 	
 	# ask timer, which is part of Digital Lab Sim tool,
 	# to generate interrupts every 40 instructions
 	# (see Digital Lab Sim help file for detail)
 	li s1, 0xffff0013
 	li s0, 1
 	sb s0, 0(s1)       
	
	j process_1        # start running process_1
	
	
# only registers s0-s3 are saved as process context 
# and can be used by the process code.

# ---------------------------------------

		
process_1:
	li s1,0xffff0010
loop_1:
	li s0,0x3f
	sb s0,0(s1)
	li s0,0x06
	sb s0,0(s1)
	li s0,0x5B
	sb s0,0(s1)
	li s0,0x4F
	sb s0,0(s1)
	j loop_1
	
# ---------------------------------------
	
process_2:
	li s1,0xffff0011
loop_2:
	li s0,0x3f
	sb s0,0(s1)
	li s0,0x06
	sb s0,0(s1)
	li s0,0x5B
	sb s0,0(s1)
	li s0,0x4F
	sb s0,0(s1)
	j loop_2
	
# ---------------------------------------
	

trap_handler: 

	# save process context (i.e. CPU registers) into the current trap frame
	
	csrw s0,mscratch    # copy value of s0 into mscratch temporarily
	la s0, current_process_trap_frame
	lw s0, 0(s0)        # load address of the current trap_frame into s0
	sw s1, 8(s0)        # save value of s1 into the trap frame
	sw s2,12(s0)        # save value of s2 into the trap frame
	sw s3,16(s0)        # save value of s3 into the trap frame
	csrr s1, mscratch   # get value of s0 from uscratch into s1
	sw s1, 4(s0)        # save value of s0 into the trap frame
	csrr s1, mepc       # get value of pc from mepc into s1
	sw s1, 0(s0)        # save value of pc into the trap frame

	# switch to the next process
	
	lw s1, 20(s0)       # load address of the next trap frame to run
	la s0, current_process_trap_frame
        sw s1, 0(s0)        # save it into the currernt trap frame pointer  

	# restore process context (CPU registers) from the selected trap frame 
	# and continue running
	
	mv s0,s1            # address of selected process trap frame in s0
	lw s1,0(s0)         # saved value of pc in s1
	csrw s1,mepc        # we put it to mepc for mret to consume
	lw s1,4(s0)         # load saved value of s0
	csrw s1,mscratch    # put it to mscratch temporarily
	lw s1,8(s0)         # restore saved value of s1
	lw s2,12(s0)        # restore saved value of s2
	lw s3,16(s0)        # restore saved value of s3
        csrr s0,mscratch    # restore s0 from mscratch
        
	mret                # restore pc from mepc and continue running
	                    # selected process
		
	.data

# Pointer to the trap frame corresponding to the currently running process

current_process_trap_frame:
	.word	trap_frame_1
	
# Different trap frames are used for storing contexts of
# individual processes

trap_frame_1:
	.word process_1    # pc    (trap_frame + 0)  - initialise to the starting address
	.word 0            # s0    (trap_frame + 4)
	.word 0            # s1    (trap_frame + 8) 
	.word 0            # s2    (trap_frame + 12) 
	.word 0            # s3    (trap_frame + 16) 
	.word trap_frame_2 # next  (trap_frame + 20)
	
trap_frame_2:
	.word process_2    # pc    (trap_frame + 0)  - initialise to the starting address
	.word 0            # s0    (trap_frame + 4)
	.word 0            # s1    (trap_frame + 8)
	.word 0            # s2    (trap_frame + 12) 
	.word 0            # s3    (trap_frame + 16) 
	.word trap_frame_1 # next  (trap_frame + 20)

