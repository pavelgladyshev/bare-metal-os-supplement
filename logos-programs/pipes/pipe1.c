#include "libc.h"
int main()
{
  int p[2];
  pipe(p);
  if (fork() == 0)
  {
     char recv_msg[14];
     close(p[1]);
     read(p[0],recv_msg,14);
     printf("received message: '%s'\n",recv_msg);
     exit(0);
  }
  close(p[0]);
  char snd_msg[]="Hello!";
  printf("parent process sending '%s'\n",snd_msg);
  write(p[1],snd_msg,strlen(snd_msg)+1);
  wait();
  printf("child process finished!\n");
  exit(0);
}
