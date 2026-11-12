/* Output and a two-hart barrier, shared by counter.c and litmus.c (illustration). */
#define UART ((volatile char *)0x10000000)   /* 16550 transmit register on virt */

void putstr(const char *s)
{
    while (*s)
        *UART = *s++;
}

void putnum(unsigned n)
{
    char buf[12];
    int i = 0;
    do { buf[i++] = '0' + n % 10; n /= 10; } while (n);
    while (i > 0)
        *UART = buf[--i];
}

/* Both harts wait here until the other one has arrived too. */
volatile int arrived;

void barrier(int *round)
{
    *round += 2;
    __atomic_fetch_add(&arrived, 1, __ATOMIC_SEQ_CST);   /* amoadd.w */
    while (arrived < *round)
        ;
}
