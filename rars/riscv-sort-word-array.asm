# Selection sort algorithm applied to an array of 5 .words
# The result is printed onto console
	
	.data

N:	.word 5      # number of elements in the array, N is the *address* of that word

A:	.word 4      # \
	.word 20     #  \
	.word 2      #   Array of 5 .words, A is the *address* of the first element
	.word 1      #  /
	.word 10     # /
	
# idea of the algorithm is straightforward: when an array is in 
# the ascending order, the first element contains the smallest value,
# the seconds element contains the second smallest value and so on.
# Thus, to sort the array, we can find the minimal number in the array 
# and swap it with the first element, then repeat the process with the
# rest of the array to find the second smallest number, and so on...

	.text
main:
	la   s0,N             # load address (N) into s0 
	lw   s1,0(s0)         # load number of elements of the array into s1
	
	la   s2,A             # load address of the first element of the array into s2

sortLoop:	
	# To find the minimal value in the array, I need a variable to keep
	# the minimal value discovered so far, and the address of that value in the array
	# I am going to use s3 to keep the address and s4 to keep the smallest value 
	
	mv   s3,s2            # Initially, we guess that the first element
	lw   s4,0(s3)         # already contains the minimal value. 
	
	# To scan the rest of the array, I need two more registers:
	# I need a register to keep the number of remaining elements 
	# of the array I need to scan, and I am going to use s5 for that
	                      
	addi s5,s1,-1         # s5 = s1-1	                                                                  
	                                                                                                                                                          
	# I also need a register to keep the address of the next element of the array
	# I am going to examine - I will use s6 for that
	
	addi s6,s2,4          # we start scanning from the second element
	                      # (remember that every .word occupies *four* consecutive
	                      # memory addresses, so the second element begins in memory at 
	                      # the address s2+4)
	                      
minLoop:
	lw t0,0(s6)           # load value of the next element of the array into t0
        
	bge t0,s4,next        # if the loaded value is greater or equal that the smallest 
                              # value discovered so far, move to the next element
        
	mv s4,t0              # otherwise, we found a new, smaller value than our previous guess
	mv s3,s6              # so we keep its address in s3
                                 
next:
	addi s6,s6,4          # skip over four memory addresses to get to the next .word 
        
	addi s5,s5,-1         # decrement the number of remaining elements to examine
	bgt s5,zero,minLoop   # while the number of remaining elements > 0, do the loop again

	# all elements have been examined. s4 keeps the minimal value and s3 keeps the address
	# of the coresponding .word in the array. Let's now swap it with the first element
	
	lw t1,0(s2)            # t1 = old value of the first element of the array	                      
	sw s4,0(s2)            # write the smallest found value into the first element                      
	sw t1,0(s3)            # write old value of the first element where the smalles value 
	                       # used to be
	                       
	# to repeat the process with the rest of the array, we simply move s2 to the next element 
	# of the array
	
	addi s2,s2,4
	
	# and decrement the number of elements in the array
	
	addi s1,s1,-1
	
	# if the number of remaining elements is greater than 1,  
	
	li t2,1
	bgt s1,t2,sortLoop   	# repeat finding the minimal element and swapping it with the first.

	# the array is now sorted. 
	
	# For this example's sake, I choose to print it out using syscall 1 (to print the numbers) 
	# and syscall 11 (to print '\n' between them)
        
	la t0,A         # t0 = address (A) of the first element of the array
	la t1,N         # t1 = address (N) of the number of elements in the array
	lw t2,0(t1)     # t2 = number of elements in the array
        
printLoop:
	lw a0,0(t0)     # a0 = value of the element we are printing
	li a7,1         # syscall #1 (printInt) 
	ecall
	
	li a0,'\n'      # a0 = newline character code
	li a7,11        # syscall # 11 (printChar)
	ecall
        
	addi t0,t0,4    # move to the next element (.word) of the array 
	addi t2,t2,-1   # reduce the number of remaining elements to print by 1
        
	# while that number is >0
	bgt t2,zero, printLoop  # repeat printing loop.
                     
	li a7,10        # syscall #10 (exit the program)
	ecall
