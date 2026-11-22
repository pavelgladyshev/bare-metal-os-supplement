/* straddle - a read() buffer with two valid ends and an unmapped middle (book illustration, Chapter 21) */
#include "libc.h"

int main(void)
{
    int p[2], fd, n, i;
    char c;
    unsigned char *code = (unsigned char *)0x00400000;

    pipe(p);
    if (fork() == 0) {
        close(p[1]);
        read(p[0], &c, 1);              /* wait for the parent */
        printf("child: my first code bytes:");
        for (i = 0; i < 6; i++)
            printf(" %x", code[i]);
        printf("\n");
        exit(0);
    }
    close(p[0]);
    fd = open("/etc/hello.txt", O_RDONLY);
    n = read(fd, (void *)0x0040FFF8, 0xF000C);
    printf("parent: read(fd, 0x40fff8, 0xf000c) returned %d\n", n);
    close(fd);
    write(p[1], "x", 1);
    close(p[1]);
    wait();
    return 0;
}
