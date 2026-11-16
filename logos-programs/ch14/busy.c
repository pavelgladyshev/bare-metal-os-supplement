#include "libc.h"

int main(void)
{
    char line[64];
    int i;
    volatile int j;

    if (fork() == 0) {
        for (i = 0; i < 10; i++) {
            write(1, ".", 1);
            for (j = 0; j < 500; j++)
                ;
        }
        exit(0);
    }
    puts("type a line:");
    gets(line, sizeof(line));
    printf("\nparent read '%s'\n", line);
    wait();
    return 0;
}
