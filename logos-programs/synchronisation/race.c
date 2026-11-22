/*
 * race - two processes increment a shared counter without synchronisation
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
    for (i = 0; i < n; i++)
        (*counter)++;
    if (pid == 0)
        exit(0);

    wait();
    printf("counter = %d, expected %d\n", *counter, 2 * n);
    shmdt(id);
    return 0;
}
