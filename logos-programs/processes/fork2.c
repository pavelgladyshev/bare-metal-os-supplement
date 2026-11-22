#include "libc.h"
int main(int argc, char *argv[])
{
  char *a[3];
  a[0]="/bin/cat";
  a[1]="/etc/hello.txt";
  a[2]=0; // End of arguments
  if (fork() == 0)
  {
     exec("/bin/cat",a); // takes file path to the executable file, never returns
  }
  wait();
  puts("Contents of hello.txt printed\n");
  exit(0);
}
