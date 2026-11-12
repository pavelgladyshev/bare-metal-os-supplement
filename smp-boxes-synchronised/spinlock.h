/*
 * Example software running in SMP RISC-V Simulated in QEMU. An implementation of
 * spinlock adopted from xv6-riscv, (c) 2006-2019 Kaashoek, Morris, Cox, MIT: see LICENSE-xv6.txt
 */

#pragma once

// Mutual exclusion lock.
struct spinlock {
    unsigned int locked;       // Is the lock held?

    // For debugging:
    char *name;        // Name of lock.
};

// Acquire the lock.
// CPU hart loops (spins) until the lock is acquired.
void acquire(struct spinlock *lk);

// Release the lock.
void release(struct spinlock *lk);


