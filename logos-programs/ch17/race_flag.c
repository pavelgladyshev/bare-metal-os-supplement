/*
 * race_flag - the shared counter of race.c guarded by a home-made lock (a flag)
 */
#include "libc.h"

int main(int argc, char *argv[]) {
    int id, pid, i, n = 10000;
    volatile int *counter, *busy;

    if (argc > 1)
        n = atoi(argv[1]);

    id = shmget(17, IPC_CREAT);         /* a shared memory segment */
    counter = (volatile int *)shmat(id);
    busy = counter + 1;                 /* the lock: 1 = taken */
    *counter = 0;
    *busy = 0;

    pid = fork();                       /* both processes run the loop */
    for (i = 0; i < n; i++) {
        while (*busy)                   /* wait until the lock is free */
            ;
        *busy = 1;                      /* take it */
        (*counter)++;
        *busy = 0;                      /* give it back */
    }
    if (pid == 0)
        exit(0);

    wait();
    printf("counter = %d, expected %d\n", *counter, 2 * n);
    shmdt(id);
    return 0;
}
