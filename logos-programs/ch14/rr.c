#include "libc.h"

static void worker(char c)
{
    int i;
    volatile int j;
    for (i = 0; i < 40; i++) {
        write(1, &c, 1);
        for (j = 0; j < 20; j++)
            ;                       /* a little work between letters */
    }
    exit(0);
}

int main(void)
{
    if (fork() == 0)
        worker('a');
    if (fork() == 0)
        worker('b');
    wait();
    wait();
    return 0;
}
