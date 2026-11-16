#include "libc.h"

int main(void)
{
    volatile int j;

    if (fork() == 0) {
        for (j = 0; j < 2000; j++)
            ;
        puts("orphan: exiting with code 5");
        exit(5);
    }
    return 0;                       /* the parent does not wait */
}
