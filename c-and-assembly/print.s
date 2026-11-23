# Example software running in Logisim RISC-V Computer System model by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0

    .text

    # void print(const char *s) - prints a string on the computer's terminal
    #
    # input: a0 = address of the first character of the string, which ends with a zero byte
    #
    # This is an example of a function written in assembly language.
    # According to the RISC-V function calling convention (ilp32), CPU registers t0-t6 and a0-a7
    # can be modified by the function and do not need to be saved on the stack
    # as long as this function is not calling other functions.

    .globl print

print:
    li t0,0xffff000c    # address of the terminal's data register
loop:
    lbu t1,0(a0)        # load the next character of the string
    beqz t1,done        # a zero byte marks the end of the string
    sw t1,0(t0)         # write the character to the terminal
    addi a0,a0,1        # move to the next character of the string
    j loop              # keep going until the end of the string
done:
    jr ra               # return
