/*
 * prodcons - producers and consumers with a buffer of N spaces and three semaphores
 * (a port of the 2022/23 xv6 example prod_cons.c)
 */
#include "libc.h"

#define N 3                          /* number of buffer spaces */

struct buffer {
    int in_use;
    int data;
};

struct buffer_space {
    struct buffer buf[N];            /* array of N buffers */
    int lp;                          /* index of the last "produced" buf[] */
    int lc;                          /* index of the last "consumed" buf[] */
};

static volatile struct buffer_space *b;   /* in a shared memory segment */
static int Sempty, Sfull, Sm;              /* semaphore ids */

void produce(int d)
{
    semwait(Sempty);
    semwait(Sm);
    /* critical section: find an unused buffer and fill it */
    while (b->buf[b->lp].in_use)
        b->lp = (b->lp + 1) % N;
    b->buf[b->lp].in_use = 1;
    b->buf[b->lp].data = d;
    printf("Produced data = %d into buf[%d]\n", d, b->lp);
    sempost(Sm);
    sempost(Sfull);
}

int consume(void)
{
    int d;
    semwait(Sfull);
    semwait(Sm);
    /* critical section: find a full buffer and empty it */
    while (!b->buf[b->lc].in_use)
        b->lc = (b->lc + 1) % N;
    b->buf[b->lc].in_use = 0;
    d = b->buf[b->lc].data;
    printf("Consumed data = %d from buf[%d]\n", d, b->lc);
    sempost(Sm);
    sempost(Sempty);
    return d;
}

#define WORK 3000                    /* length of the consumer's "work" */

void producer(int start)             /* produces 5 items, start..start+4 */
{
    int i;
    for (i = 0; i < 5; i++)
        produce(start + i);
    exit(0);
}

void consumer(void)                  /* consumes 5 items */
{
    int i;
    volatile int w;
    for (i = 0; i < 5; i++) {
        consume();
        for (w = 0; w < WORK; w++)   /* do some work on the item */
            ;
    }
    exit(0);
}

int main(void)
{
    int id, i;

    id = shmget(1800, IPC_CREAT);
    b = (volatile struct buffer_space *)shmat(id);
    b->lp = 0;
    b->lc = 0;
    for (i = 0; i < N; i++)
        b->buf[i].in_use = 0;

    Sempty = semget(1801, N, IPC_CREAT);
    Sfull  = semget(1802, 0, IPC_CREAT);
    Sm     = semget(1803, 1, IPC_CREAT);

    if (fork() == 0) producer(0);
    if (fork() == 0) consumer();
    if (fork() == 0) producer(5);
    if (fork() == 0) consumer();

    wait();
    wait();
    wait();
    wait();

    semclose(Sempty);
    semclose(Sfull);
    semclose(Sm);
    shmdt(id);
    return 0;
}
