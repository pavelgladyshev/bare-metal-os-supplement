/* shmpt - attach one shared-memory segment (book illustration, Chapter 21) */
#include "libc.h"

int main(void)
{
    int id = shmget(7, IPC_CREAT);
    void *p = shmat(id);
    printf("segment %d attached at 0x%x\n", id, (unsigned int)p);
    return 0;
}
