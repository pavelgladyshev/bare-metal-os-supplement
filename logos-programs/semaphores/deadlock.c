/*
 * deadlock - two workers take two binary semaphores, A and B.
 * X takes A then B; Y takes B then A, or, with the argument "ordered", A then B.
 * The parent is a watchdog: it checks a status record in shared memory, and when
 * neither worker completes a round for STUCK checks it prints what each holds and
 * waits for, and kills one of them.
 */
#include "libc.h"

#define ROUNDS 3                     /* rounds each worker makes */
#define WORK   300                   /* length of the "work" loop */
#define STUCK  20                    /* checks without progress = deadlock */

struct status {
    int done;                        /* completed rounds */
    int holds;                       /* bit 0: holds A, bit 1: holds B */
    int wants;                       /* 0: nothing, 1: A, 2: B */
};

static volatile struct status *st;   /* st[0] is X, st[1] is Y; in a shared segment */
static int sem[3];                   /* sem[1] is A, sem[2] is B */

static void work(void)
{
    volatile int w;
    for (w = 0; w < WORK; w++)
        ;
}

static void worker(int me, int first, int second)
{
    int r;
    for (r = 0; r < ROUNDS; r++) {
        st[me].wants = first;
        semwait(sem[first]);
        st[me].holds |= first;
        st[me].wants = 0;
        work();
        st[me].wants = second;
        semwait(sem[second]);
        st[me].holds |= second;
        st[me].wants = 0;
        work();
        st[me].done++;
        sempost(sem[second]);
        st[me].holds &= ~second;
        sempost(sem[first]);
        st[me].holds &= ~first;
    }
    exit(0);
}

static void name(int set)            /* print a set of semaphores: bit 0 is A, bit 1 is B */
{
    if (set == 0)
        printf("nothing");
    else if (set == 1)
        printf("A");
    else if (set == 2)
        printf("B");
    else
        printf("A and B");
}

static void report(void)
{
    int i;
    printf("no progress after %d checks\n", STUCK);
    for (i = 0; i < 2; i++) {
        printf("%c: done %d rounds, holds ", i == 0 ? 'X' : 'Y', st[i].done);
        name(st[i].holds);
        printf(", waits for ");
        name(st[i].wants);
        printf("\n");
    }
}

int main(int argc, char *argv[])
{
    int id, x, y, last = -1, idle = 0, killed = 0;
    int ordered = argc > 1 && strcmp(argv[1], "ordered") == 0;

    id = shmget(1820, IPC_CREAT);
    st = (volatile struct status *)shmat(id);
    st[0].done = st[0].holds = st[0].wants = 0;
    st[1].done = st[1].holds = st[1].wants = 0;
    sem[1] = semget(1821, 1, IPC_CREAT);         /* A */
    sem[2] = semget(1822, 1, IPC_CREAT);         /* B */

    x = fork();
    if (x == 0)
        worker(0, 1, 2);                         /* X: A, then B */
    y = fork();
    if (y == 0) {
        if (ordered)
            worker(1, 1, 2);                     /* Y: A, then B */
        else
            worker(1, 2, 1);                     /* Y: B, then A */
    }

    for (;;) {                                   /* the watchdog */
        int total;
        work();
        total = st[0].done + st[1].done;
        if (total == 2 * ROUNDS) {
            printf("X and Y finished %d rounds each\n", ROUNDS);
            break;
        }
        if (total != last) {
            last = total;
            idle = 0;
        } else if (++idle == STUCK) {
            report();
            if (!killed) {
                printf("deadlock: killing %d (Y)\n", y);
                kill(y);
                killed = 1;
                idle = 0;
            } else {
                printf("X is still stuck: killing %d\n", x);
                kill(x);
                break;
            }
        }
    }
    wait();
    wait();
    semclose(sem[1]);
    semclose(sem[2]);
    shmdt(id);
    return 0;
}
