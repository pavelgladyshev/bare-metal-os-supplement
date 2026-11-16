#include "libc.h"

int main(void)
{
    char *argv[2];

    if (fork() == 0) {
        if (fork() == 0) {
            argv[0] = "ps";
            argv[1] = 0;
            exec("/bin/ps", argv);  /* grandchild: become ps */
            exit(127);
        }
        wait();                     /* child waits for the grandchild */
        exit(0);
    }
    wait();                         /* parent waits for the child */
    return 0;
}
