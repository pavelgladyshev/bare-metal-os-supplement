#include "libc.h"
int main(int argc, char *argv[])
{
  if (fork() == 0)
  {
     puts("child process");
     exit(1);
  } else {

        puts("parent process");
        wait();
        puts("child process finished");
        exit(0);
    }
}
