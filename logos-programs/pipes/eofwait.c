/* eofwait - a parent reads its child's output to end of file before it calls wait
 * (book illustration, Chapter 16) */
#include "libc.h"

int main(void)
{
    int p[2], n, total = 0;
    char buf[16];

    pipe(p);
    if (fork() == 0) {
        write(p[1], "abc", 3);
        exit(0);
    }
    close(p[1]);
    for (;;) {
        n = read(p[0], buf, sizeof(buf));
        printf("read returned %d\n", n);
        if (n <= 0)
            break;
        total += n;
    }
    wait();
    printf("total %d\n", total);
    return 0;
}
