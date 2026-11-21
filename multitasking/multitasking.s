# To run this program type make gui and, in Logisim's window, 
# choose Simulate -> Auto-Tick Enabled

	.equ TIME_SLICE, 2000   # clock cycles from one timer interrupt to the next
                
        .text
main:
	# set-up trap handler
 	la s0,trap_handler
 	csrw mtvec,s0       # set mtvec = address of the handler

	# create the two processes: fill in their trap frames
	# and make trap_frame_1 the current one
	la s0, trap_frame_1
	la s1, process_1
	sw s1, 0(s0)        # pc of process 1 = its starting address
	la s1, trap_frame_2
	sw s1, 20(s0)       # next trap frame after trap_frame_1 is trap_frame_2
	la s0, trap_frame_2
	la s1, process_2
	sw s1, 0(s0)        # pc of process 2 = its starting address
	la s1, trap_frame_1
	sw s1, 20(s0)       # next trap frame after trap_frame_2 is trap_frame_1
	la s0, current_process_trap_frame
	sw s1, 0(s0)        # process 1 will run first

 	# ask timer to generate the first interrupt TIME_SLICE clock cycles
 	# from now: set mtimecmp = mtime + TIME_SLICE. Both registers have
 	# 64 bits, the low word at the address given and the high word 4 above
	li s1, 0x02004000   # address of mtimecmp
	li s2, -1
	sw s2, 0(s1)        # mtimecmp, low word: all ones for now
1:	li s1, 0x0200bff8   # address of mtime
	lw s2, 4(s1)        # s2 = mtime, high word
	lw s3, 0(s1)        # s3 = mtime, low word
	lw s1, 4(s1)        # the high word again
	bne s1, s2, 1b      # it changed while we were reading: read again
	li s1, TIME_SLICE
	add s3, s3, s1      # low word + TIME_SLICE
	sltu s1, s3, s1     # s1 = 1 if the sum is below TIME_SLICE: a carry
	add s2, s2, s1      # s2:s3 = mtime + TIME_SLICE
	li s1, 0x02004000   # address of mtimecmp
	sw s2, 4(s1)        # mtimecmp, high word
	sw s3, 0(s1)        # mtimecmp, low word: the new value
 	
 	# enable processing of interrupt requests from timer
 	li s1,0x80      
 	csrw mie,s1         # set mie = 0x80 

 	# enable interrupts in CPU
        csrsi mstatus,8    # set interrupt enable bit in mstatus (3) 
	
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
	
	csrw mscratch,s0    # copy value of s0 into mscratch temporarily
	la s0, current_process_trap_frame
	lw s0, 0(s0)        # load address of the current trap_frame into s0
	sw s1, 8(s0)        # save value of s1 into the trap frame
	sw s2,12(s0)        # save value of s2 into the trap frame
	sw s3,16(s0)        # save value of s3 into the trap frame
	csrr s1, mscratch   # get value of s0 from mscratch into s1
	sw s1, 4(s0)        # save value of s0 into the trap frame
	csrr s1, mepc       # get value of pc from mepc into s1
	sw s1, 0(s0)        # save value of pc into the trap frame

	# ask timer to generate the next interrupt TIME_SLICE clock cycles
	# from now: set mtimecmp = mtime + TIME_SLICE, as in main. This
	# also takes the present interrupt request away. It uses s1, s2
	# and s3, which have just been saved

	li s1, 0x02004000   # address of mtimecmp
	li s2, -1
	sw s2, 0(s1)        # mtimecmp, low word: all ones for now
1:	li s1, 0x0200bff8   # address of mtime
	lw s2, 4(s1)        # s2 = mtime, high word
	lw s3, 0(s1)        # s3 = mtime, low word
	lw s1, 4(s1)        # the high word again
	bne s1, s2, 1b      # it changed while we were reading: read again
	li s1, TIME_SLICE
	add s3, s3, s1      # low word + TIME_SLICE
	sltu s1, s3, s1     # s1 = 1 if the sum is below TIME_SLICE: a carry
	add s2, s2, s1      # s2:s3 = mtime + TIME_SLICE
	li s1, 0x02004000   # address of mtimecmp
	sw s2, 4(s1)        # mtimecmp, high word
	sw s3, 0(s1)        # mtimecmp, low word: the new value

	# switch to the next process
	
	lw s1, 20(s0)       # load address of the next trap frame to run
	la s0, current_process_trap_frame
        sw s1, 0(s0)        # save it into the current trap frame pointer  

	# restore process context (CPU registers) from the selected trap frame 
	# and continue running
	
	mv s0,s1            # address of selected process trap frame in s0
	lw s1,0(s0)         # saved value of pc in s1
	csrw mepc,s1        # we put it to mepc for mret to consume
	lw s1,4(s0)         # load saved value of s0
	csrw mscratch,s1    # put it to mscratch temporarily
	lw s1,8(s0)         # restore saved value of s1
	lw s2,12(s0)        # restore saved value of s2
	lw s3,16(s0)        # restore saved value of s3
        csrr s0,mscratch    # restore s0 from mscratch
        
	mret                # restore pc from mepc and continue running
	                    # selected process
		
	.section .bss

# Pointer to the trap frame corresponding to the currently running process

current_process_trap_frame:
	.space 4           # main sets it to trap_frame_1
	
# Different trap frames are used for storing contexts of
# individual processes

trap_frame_1:
	.space 4           # pc    (trap_frame + 0)  - main sets it to the starting address
	.space 4           # s0    (trap_frame + 4)
	.space 4           # s1    (trap_frame + 8) 
	.space 4           # s2    (trap_frame + 12) 
	.space 4           # s3    (trap_frame + 16) 
	.space 4           # next  (trap_frame + 20) - main sets it to trap_frame_2
	
trap_frame_2:
	.space 4           # pc    (trap_frame + 0)  - main sets it to the starting address
	.space 4           # s0    (trap_frame + 4)
	.space 4           # s1    (trap_frame + 8)
	.space 4           # s2    (trap_frame + 12) 
	.space 4           # s3    (trap_frame + 16) 
	.space 4           # next  (trap_frame + 20) - main sets it to trap_frame_1
