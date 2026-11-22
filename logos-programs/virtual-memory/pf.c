/* pf - provoke one page fault, chosen by the argument (book illustration, Chapter 20) */
#include "libc.h"

int main(int argc, char *argv[])
{
    if (argc < 2) {
        puts("usage: pf null|kern|tty|jump|past|code");
        return 1;
    }
    if (strcmp(argv[1], "null") == 0) {
        volatile int *p = (int *)0;
        printf("read %d\n", *p);
    } else if (strcmp(argv[1], "kern") == 0) {
        volatile char *p = (char *)0x00100000;
        *p = 0;
    } else if (strcmp(argv[1], "tty") == 0) {
        volatile char *p = (char *)0xFFFF000C;
        *p = '!';
    } else if (strcmp(argv[1], "jump") == 0) {
        void (*volatile f)(void) = (void (*)(void))0;
        f();
    } else if (strcmp(argv[1], "past") == 0) {
        volatile char *p = (char *)0x00410000;
        *p = 0;
    } else if (strcmp(argv[1], "code") == 0) {
        volatile unsigned int *p = (unsigned int *)main;
        *p = *p;
        puts("wrote to my own code");
    }
    puts("still alive");
    return 0;
}
