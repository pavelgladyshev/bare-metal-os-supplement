/* Test programs for the simulated computer by Pavel Gladyshev
   licensed under Creative Commons Attribution International license 4.0

   The program in the ROM, from address 0; its variables and its stack in the RAM. */
OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv", "elf32-littleriscv")
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  rom (rxi)  : ORIGIN = 0x00000000, LENGTH = 64K
  ram (w!i)  : ORIGIN = 0x00100000, LENGTH = 1M
}

SECTIONS
{
  .init : { *(.init) } > rom
  .text : { *(.text) *(.text.*) } > rom
  .rodata : { *(.rodata) *(.rodata.*) } > rom

  .bss : { *(.bss) *(.sbss) *(COMMON) } > ram

  PROVIDE(__stack_init = ORIGIN(ram) + LENGTH(ram));
}
