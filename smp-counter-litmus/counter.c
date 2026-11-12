/* Two harts increment one shared counter, with and without a lock (illustration). */
void putstr(const char *s);
void putnum(unsigned n);
void barrier(int *round);

#define N 100000            /* increments per hart */

volatile int counter;       /* the shared counter  */
volatile int lock;          /* 0 = free, 1 = held  */

/* Spin lock with amoswap: swap a 1 in; we own the lock if a 0 came out. */
static void acquire_swap(volatile int *l)
{
    int old;
    do {
        asm volatile("amoswap.w.aq %0, %1, (%2)"
                     : "=r"(old) : "r"(1), "r"(l) : "memory");
    } while (old != 0);
}

static void release_swap(volatile int *l)
{
    asm volatile("amoswap.w.rl zero, zero, (%0)" : : "r"(l) : "memory");
}

/* Spin lock with lr/sc: reserve the word, check for 0, store 1 conditionally. */
static void acquire_lrsc(volatile int *l)
{
    int tmp;
    asm volatile("1: lr.w.aq %0, (%1)\n"
                 "   bnez    %0, 1b\n"
                 "   sc.w    %0, %2, (%1)\n"
                 "   bnez    %0, 1b"
                 : "=&r"(tmp) : "r"(l), "r"(1) : "memory");
}

static void release_fence(volatile int *l)
{
    asm volatile("fence rw, w\n"
                 "sw    zero, 0(%0)" : : "r"(l) : "memory");
}

static void plain(void)     { counter++; }
static void swap_lock(void) { acquire_swap(&lock); counter++; release_swap(&lock); }
static void lrsc_lock(void) { acquire_lrsc(&lock); counter++; release_fence(&lock); }
static void amo_add(void)   { asm volatile("amoadd.w zero, %0, (%1)"
                                           : : "r"(1), "r"(&counter) : "memory"); }

static struct { const char *name; void (*inc)(void); } tests[] = {
    { "counter++, no lock    ", plain },
    { "amoswap spin lock     ", swap_lock },
    { "lr/sc spin lock       ", lrsc_lock },
    { "amoadd.w, no lock     ", amo_add },
};

void main(int hart)
{
    int round = 0;
    for (int t = 0; t < 4; t++) {
        if (hart == 0)
            counter = 0;
        barrier(&round);                 /* start together */
        for (int i = 0; i < N; i++)
            tests[t].inc();
        barrier(&round);                 /* wait until both have finished */
        if (hart == 0) {
            putstr(tests[t].name);
            putnum(counter);
            putstr("\n");
        }
    }
}
