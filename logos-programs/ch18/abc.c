/*
 * abc - ordering the critical sections of three processes with semaphores
 * (a port of the 2022/23 xv6 example abc.c)
 *
 *   A: non-critical code; wait(Sa); critical section A; signal(Sb); non-critical code
 *   B: non-critical code; wait(Sb); critical section B; signal(Sc); non-critical code
 *   C: non-critical code; wait(Sc); critical section C; signal(Sa); non-critical code
 */
#include "libc.h"

static int Sa, Sb, Sc;                      /* semaphore ids */

void A(void)
{
    printf("AAAAAAA");                      /* non-critical code */
    semwait(Sa);
    printf("\nA's critical section\n");     /* critical section A */
    sempost(Sb);
    exit(0);
}

void B(void)
{
    printf("BBBBBB");                       /* non-critical code */
    semwait(Sb);
    printf("\nB's critical section\n");     /* critical section B */
    sempost(Sc);
    exit(0);
}

void C(void)
{
    printf("CCCCCC");                       /* non-critical code */
    semwait(Sc);
    printf("\nC's critical section\n");     /* critical section C */
    sempost(Sa);
    exit(0);
}

int main(void)
{
    Sa = semget(1811, 1, IPC_CREAT);
    Sb = semget(1812, 0, IPC_CREAT);
    Sc = semget(1813, 0, IPC_CREAT);

    if (fork() == 0) C();                   /* the wrong order, on purpose */
    if (fork() == 0) B();
    if (fork() == 0) A();

    wait();
    wait();
    wait();

    semclose(Sa);
    semclose(Sb);
    semclose(Sc);
    return 0;
}
