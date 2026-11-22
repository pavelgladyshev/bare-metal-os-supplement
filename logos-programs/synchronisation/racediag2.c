/*
 * racediag2 - how long is a quantum? Only the child increments the shared counter;
 * the parent watches it and counts how often it has changed since the parent last ran.
 */
#include "libc.h"

int main(int argc, char *argv[]) {
    int id, pid, i, n = 10000, last = 0, turns = 0;
    volatile int *counter;

    if (argc > 1)
        n = atoi(argv[1]);

    id = shmget(17, IPC_CREAT);         /* a shared memory segment */
    counter = (volatile int *)shmat(id);
    *counter = 0;

    pid = fork();
    if (pid == 0) {                     /* the child increments */
        for (i = 0; i < n; i++)
            (*counter)++;
        exit(0);
    }
    while (last < n) {                  /* the parent watches */
        int now = *counter;
        if (now != last) {
            turns++;
            last = now;
        }
    }
    wait();
    printf("counter=%d child turns seen=%d\n", *counter, turns);
    shmdt(id);
    return 0;
}
