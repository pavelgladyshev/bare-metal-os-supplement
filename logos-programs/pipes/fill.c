#include "libc.h"

int main(void)
{
    int p[2], n, k, total = 0, reads = 0;
    char buf[600], r[100];

    memset(buf, 'x', sizeof(buf));
    pipe(p);
    if (fork() == 0) {               /* child: reader */
        close(p[1]);
        while ((k = read(p[0], r, sizeof(r))) > 0) {
            total += k;
            reads++;
        }
        printf("child: %d bytes in %d reads, then read returned %d\n",
               total, reads, k);
        exit(0);
    }
    close(p[0]);                     /* parent: writer */
    n = write(p[1], buf, 600);
    close(p[1]);
    wait();
    printf("parent: write(p[1], buf, 600) returned %d\n", n);
    return 0;
}
