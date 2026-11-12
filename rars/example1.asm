.text		       # the following is a program
li x20, 25         # x20 = 25
li x21, 7          # x21 = 7
li x22, 6          # x22 = 6
add x23, x20, x21  # x23 = x20+x21 = 25+7 = 32
mul x24, x23, x22  # x24 = x23*x22 = 32*6 = 192   
li  x17, 1         # print integer   
mv  x10, x24       # a0 (x10) = integer to print   
ecall
li  x17, 10        # terminate program   
ecall
