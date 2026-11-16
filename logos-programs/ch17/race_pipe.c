/*
 * race_pipe - the shared counter of race.c guarded by a pipe holding one token
 */
#include "libc.h"

int main(int argc, char *argv[]) {
    int lock[2]; char token = 'T';
    int id, pid, i, n = 10000;
    volatile int *counter;

    if (argc > 1)
        n = atoi(argv[1]);

    id = shmget(17, IPC_CREAT);         /* a shared memory segment */
    counter = (volatile int *)shmat(id);
    *counter = 0;

    pipe(lock);                         /* the lock: a pipe ... */
    write(lock[1], &token, 1);          /* ... holding one token */

    pid = fork();                       /* both processes run the loop */
    for (i = 0; i < n; i++) {
        read(lock[0], &token, 1);       /* acquire: take the token */
        (*counter)++;
        write(lock[1], &token, 1);      /* release: put it back */
    }
    if (pid == 0)
        exit(0);

    wait();
    printf("counter = %d, expected %d\n", *counter, 2 * n);
    shmdt(id);
    return 0;
}
