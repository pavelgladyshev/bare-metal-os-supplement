# This example prints two strings of text "Hello" and then "Goodbye"
# using a subroutine labeled puts

        # Data area - in RAM
        .data
hi:     .asciz "Hello\n"     # equivalent to .byte 'H','e','l','l','o','\n',0
bye:    .asciz "Goodbye\n"   # equivalent to .byte 'G','o','o','d','b','y','e','\n',0

        # Program text - in ROM
        .text
start:  la s0,hi             # load address of (the first character of) hi into s0
        jal puts             # call puts (saves the address of the next instruction "la s0,bye" in ra) 
        la s0,bye            # load address of (the first character of) bye into s0 
        jal puts             # call puts (saves the address of the next instruction "li a7,10" in ra)
        li a7,10             # load syscall number 10 (Exit) to a7   
        ecall                # terminate this program

        # puts - subroutine that prints the ASCII string, whose starting address is
        #        given in s0. The end of the string is signalled by the byte with the value 0
        #        puts uses syscall 11 (PrintChar) to print individual characters
        #
        # input: s0 - address of the string to print
        # output: none
        # modified registers: t0,t1,a0,a7
        
puts:   mv t0,s0
loop:   lb t1,0(t0)
        beq t1,zero,quit
        mv a0,t1
        li a7,11
        ecall
        addi t0,t0,1
        j loop
quit:   jr ra                # jump back into the main program to the address saved in ra.
                             # By the way, what would happen if we use jal to call another
                             # subroutine from inside puts? ;)
