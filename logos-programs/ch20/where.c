/* where - where do main, a global and a local live? (book illustration, Chapter 20) */
#include "libc.h"

int counter = 1;
char *words[] = {"one", "two", 0};

int main(void)
{
    int local = 0;
    int pid;

    printf("main at 0x%x, counter at 0x%x, local at 0x%x\n",
           (unsigned int)main, (unsigned int)&counter, (unsigned int)&local);
    printf("words[0] = %s, words[1] = %s\n", words[0], words[1]);
    pid = fork();
    if (pid == 0) {
        counter = 100;
        printf("child  (PID %d): counter at 0x%x is %d\n", getpid(), (unsigned int)&counter, counter);
        exit(0);
    }
    wait();
    printf("parent (PID %d): counter at 0x%x is %d\n", getpid(), (unsigned int)&counter, counter);
    return local;
}
