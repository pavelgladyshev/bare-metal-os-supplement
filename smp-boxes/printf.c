//
// formatted console output -- printf, panic.
//
// Adapted from the source code of xv6-riscv, Copyright (c) 2006-2019 Frans Kaashoek,
// Robert Morris, Russ Cox, Massachusetts Institute of Technology, used under the MIT
// licence: see LICENSE-xv6.txt at the top of this repository.
//

#include <stdarg.h>

#include "spinlock.h"

typedef unsigned int uint;
typedef unsigned long int uint64;

volatile int panicked = 0;

/* Print char on QEMU console */
inline static void consputc(char chr) { *((volatile char *)0x10000000) = chr; }  // write into TDR 

// lock to avoid interleaving concurrent printf's.
static struct {
  struct spinlock lock;
  int locking;
} pr = {.lock.locked = 0, .lock.name = "pr", .locking = 1};

static char digits[] = "0123456789abcdef";

static void
printint(int xx, int base, int sign)
{
  char buf[16];
  int i;
  uint x;

  if(sign && (sign = xx < 0))
    x = -xx;
  else
    x = xx;

  i = 0;
  do {
    buf[i++] = digits[x % base];
  } while((x /= base) != 0);

  if(sign)
    buf[i++] = '-';

  while(--i >= 0)
    consputc(buf[i]);
}

static void
printptr(uint64 x)
{
  int i;
  consputc('0');
  consputc('x');
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
    consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
}

// Print to the console. only understands %d, %x, %p, %s.
void
printf(char *fmt, ...)
{
  va_list ap;
  int i, c, locking;
  char *s;

  locking = pr.locking;
  if(locking)
    acquire(&pr.lock);

  if (fmt != 0)
  {  
    va_start(ap, fmt);
    for(i = 0; (c = fmt[i] & 0xff) != 0; i++){
      if(c != '%'){
        consputc(c);
        continue;
      }
      c = fmt[++i] & 0xff;
      if(c == 0)
        break;
      switch(c){
      case 'd':
        printint(va_arg(ap, int), 10, 1);
        break;
      case 'x':
        printint(va_arg(ap, int), 16, 1);
        break;
      case 'p':
        printptr(va_arg(ap, uint64));
        break;
      case 's':
        if((s = va_arg(ap, char*)) == 0)
          s = "(null)";
        for(; *s; s++)
          consputc(*s);
        break;
      case '%':
        consputc('%');
        break;
      default:
      // Print unknown % sequence to draw attention.
        consputc('%');
        consputc(c);
        break;
      }
    }
    va_end(ap);
  }

  if(locking)
    release(&pr.lock);
}
