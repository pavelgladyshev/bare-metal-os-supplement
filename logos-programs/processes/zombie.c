#include "libc.h"

static void spin(int n)
{
    volatile int j;
    for (j = 0; j < n; j++)
        ;
}

int main(void)
{
    char *argv[2];

    if (fork() == 0)
        exit(7);                    /* first child: exit at once */
    spin(3000);                     /* let it run and exit */
    if (fork() == 0) {
        argv[0] = "ps";
        argv[1] = 0;
        exec("/bin/ps", argv);      /* second child: become ps */
        exit(127);
    }
    spin(100000);                   /* let ps finish before we wait */
    printf("wait() returned %d\n", wait());
    printf("wait() returned %d\n", wait());
    return 0;
}
