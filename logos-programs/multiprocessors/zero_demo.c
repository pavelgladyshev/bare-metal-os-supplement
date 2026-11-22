/* zero_demo - executes the all-zero word, an illegal instruction
 * (book illustration, Chapter 22) */
#include "libc.h"

int main(void)
{
    puts("before the zero word");
    __asm__ volatile(".word 0");
    puts("after the zero word");
    return 0;
}
