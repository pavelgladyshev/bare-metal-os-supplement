/*
 * Example software running in Logisim RISC-V Computer System model by Pavel Gladyshev
 * licensed under Creative Commons Attribution International license 4.0
 *
 * This file defines data structure for C compatible execution context and swtch() function 
 * for switching contexts
 */

#pragma once

typedef struct context {
        void *ra;
        void *sp;
        void *gp;
        void *tp;
        void *s0;
        void *s1;
        void *a0;
        void *a1;
        void *a2;
        void *a3;
        void *a4;
        void *a5;
        void *a6;
        void *a7;
        void *s2;
        void *s3;
        void *s4;
        void *s5;
        void *s6;
        void *s7;
        void *s8;
        void *s9;
        void *s10;
        void *s11;
} context;

void swtch(context *current, context *next);
