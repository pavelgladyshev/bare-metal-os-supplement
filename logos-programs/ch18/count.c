/*
 * count - two processes add 1 to a shared integer 3000 times each.
 * With the argument "lock", a semaphore guards the addition.
 */
#include "libc.h"

#define TIMES 3000

int main(int argc, char *argv[]) {
    int id, sem, pid, i, lock = 0;
    volatile int *counter;

    if (argc > 1 && strcmp(argv[1], "lock") == 0)
        lock = 1;

    id = shmget(1830, IPC_CREAT);       /* a shared memory segment */
    counter = (volatile int *)shmat(id);
    *counter = 0;
    sem = semget(1831, 1, IPC_CREAT);   /* a semaphore with the value 1 */

    pid = fork();                       /* both processes run the loop */
    for (i = 0; i < TIMES; i++) {
        if (lock)
            semwait(sem);
        (*counter)++;
        if (lock)
            sempost(sem);
    }
    if (pid == 0)
        exit(0);

    wait();
    printf("counter = %d (expected %d)\n", *counter, 2 * TIMES);
    semclose(sem);
    shmdt(id);
    return 0;
}
