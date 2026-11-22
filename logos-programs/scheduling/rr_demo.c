/* rr_demo.c - an illustration for the chapter on scheduling */
#include "libc.h"

int main(void)
{
    char letters[3] = {'A', 'B', 'C'};
    int k, i;

    for (k = 0; k < 3; k++) {
        if (fork() == 0) {             /* child number k */
            for (i = 0; i < 30; i++)
                putchar(letters[k]);   /* one write() system call each */
            exit(0);
        }
    }
    for (k = 0; k < 3; k++)            /* parent: wait for all three */
        wait();
    putchar('\n');
    return 0;
}
