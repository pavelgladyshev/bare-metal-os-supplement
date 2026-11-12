/*
 * Example software running in Logisim RISC-V Computer System model by Pavel Gladyshev
 * licensed under Creative Commons Attribution International license 4.0
 *
 * This file defines addresses for memory mapped keyboard and TTY display
 */

#pragma once

#define TTY ((volatile unsigned int*) 0xFFFF000C)
#define RCR ((volatile unsigned int*) 0xFFFF0004)
#define RDR ((volatile unsigned int*) 0xFFFF0008)
