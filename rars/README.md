# The programs as they ran in RARS

These are the assembly-language programs of chapters 2, 12 and 13 in the form in which they ran
in the RARS simulator (the [modified RARS](https://github.com/pavelgladyshev/COMP20180-rars) of
the course that the book grew from). The book no longer uses RARS: every program here has moved
to the simulated computer, where it runs on bare metal, and is kept up to date there.

| Here | Now |
| --- | --- |
| `example1.asm`, `riscv-memory.asm`, `riscv-led.asm`, `riscv-max.asm`, `riscv-looping.asm`, `riscv-subroutine.asm`, `riscv-sort-word-array.asm` | `../assembly/` |
| `polled_kbd.asm` | `../keyboard-polled/` |
| `interrupt_kbd.asm` | `../keyboard-interrupt/` |
| `multitasking.asm` | `../multitasking/` |

The files stay here for readers of earlier printings and for comparison: `../assembly/README.md`
says what changed in the move.
