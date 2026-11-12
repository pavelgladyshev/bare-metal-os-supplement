/*
 * Simple example of a C program for RISC-V, by Pavel Gladyshev
 * Licensed under Creative Commons Attribution International License 4.0
 */

#define CONSOLE_DATA  (*(volatile int*)0xFFFF000C)

void putchar(int c) {
    CONSOLE_DATA = c;
}

void puts(const char *s) {
    while (*s != '\0') {
        putchar(*s);
        s++;
    }
}

int main(void) {
    puts("Hello world!\n");
}