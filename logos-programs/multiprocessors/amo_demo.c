/* amo_demo - executes amoswap.w.aq t0, t0, (a0), entered as a word because
 * -march=rv32im has no A extension (book illustration, Chapter 21) */
#include "libc.h"

static volatile int lock;

int main(void)
{
    register volatile int *a0 __asm__("a0") = &lock;
    register int t0 __asm__("t0") = 1;

    puts("before amoswap");
    a0 = &lock; t0 = 1;
    __asm__ volatile(".word 0x0C5522AF" : "+r"(t0) : "r"(a0) : "memory");
    printf("after amoswap: t0 = %d, lock = %d\n", t0, lock);
    return 0;
}
