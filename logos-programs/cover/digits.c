/* digits - shows a number from 0 to 99 on the computer's two seven-segment digits
 * (the command on the book's cover). Blackrock has no memory protection, so a
 * program can write to a device's registers itself. */
#include "libc.h"

#define DIGIT_RIGHT ((volatile unsigned char *)0xFFFF0010)
#define DIGIT_LEFT  ((volatile unsigned char *)0xFFFF0011)

/* the segments that draw 0 to 9: bit 0 is segment a, bit 6 is segment g */
static const unsigned char segments[10] = {
    0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f
};

int main(int argc, char **argv)
{
    int n;

    if (argc != 2) {
        puts("usage: digits <number from 0 to 99>");
        return 1;
    }
    n = atoi(argv[1]);
    if (n < 0 || n > 99) {
        puts("digits: the number must be from 0 to 99");
        return 1;
    }
    *DIGIT_LEFT = segments[n / 10];
    *DIGIT_RIGHT = segments[n % 10];
    return 0;
}
