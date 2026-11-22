/*
 * race_intr - the shared counter of race.c with interrupts disabled around the increment
 */
#include "libc.h"

int main(int argc, char *argv[]) {
    int id, pid, i, n = 10000;
    volatile int *counter;

    if (argc > 1)
        n = atoi(argv[1]);

    id = shmget(17, IPC_CREAT);         /* a shared memory segment */
    counter = (volatile int *)shmat(id);
    *counter = 0;

    pid = fork();                       /* both processes run the loop */
    for (i = 0; i < n; i++) {
        asm volatile("csrci mstatus, 8");   /* disable interrupts */
        (*counter)++;
        asm volatile("csrsi mstatus, 8");   /* enable interrupts */
    }
    if (pid == 0)
        exit(0);

    wait();
    printf("counter = %d, expected %d\n", *counter, 2 * n);
    shmdt(id);
    return 0;
}
