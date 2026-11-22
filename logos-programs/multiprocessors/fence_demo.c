/* fence_demo - one fence instruction between two lines of output
 * (book illustration, Chapter 21) */
#include "libc.h"

int main(void)
{
    puts("before fence");
    __asm__ volatile("fence rw, rw" ::: "memory");
    puts("after fence");
    return 0;
}
