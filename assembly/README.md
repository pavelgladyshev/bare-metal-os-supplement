# The programs of chapter 3

The small assembly-language programs of chapter 3, *Programming the RISC-V computer in assembly
language*. They run on bare metal, on the computer of this supplement (`../computer/`). One
Makefile builds and runs them all: `PROG` names the program (`example1` if it is not given).

```bash
make PROG=max            # build max.s: the ELF file max, the listing max.asm, the ROM image max-rom.txt
make PROG=max gui        # run it in Logisim's window
make PROG=max run        # run it in Logisim's text mode (Ctrl-C stops it)
make PROG=max debug      # the same, with the CPU waiting for gdb; then, in another terminal:
make PROG=max gdb        # gdb with the program's symbols: break halt, continue, info registers t4
make PROG=max list       # the instructions with their addresses and source lines
```

| Program | What it shows | Run it with | Where to look for the result |
| --- | --- | --- | --- |
| `example1.s` | arithmetic: (25+7)×6 | `make PROG=example1 debug`, `make PROG=example1 gdb` | register `x24` (`s8`): 192 (`p $x24` in gdb) |
| `memory.s` | loads and stores: B = A + 5 | `make PROG=memory debug`, `make PROG=memory gdb` | the variables `A` and `B` in RAM, at `0x00100000`: 1 and 6 (`x/2dw &A`) |
| `led.s` | memory-mapped output: the digit 1 | `make PROG=led gui` | the right-hand seven-segment digit; its register at `0xFFFF0010` holds `0x06` (`x/bx 0xffff0010`) |
| `max.s` | branching: the larger of two numbers | `make PROG=max debug`, `make PROG=max gdb` | register `t4`: 10 (`info registers t4`) |
| `looping.s` | a loop over a string | `make PROG=looping run` | the terminal: `Hello` |
| `subroutine.s` | a subroutine called twice | `make PROG=subroutine run` | the terminal: `Hello` and `Goodbye` |
| `sort-word-array.s` | selection sort of an array of words | `make PROG=sort-word-array debug`, `make PROG=sort-word-array gdb` | the array `A` in RAM, at `0x00100000`: 1, 2, 4, 10, 20 (`x/5dw &A`) |
| `echo.s` | polling the keyboard | `make PROG=echo run`, then type | the terminal shows each key typed |
| `example.s` | chapter 4: a variable in `.data`, which the linker script puts in the ROM | `make PROG=example debug`, `make PROG=example gdb` | register `s0`: 3; the variable `sum`, in the ROM at `0x18`: still 0, because the store is lost (`p $s0`, `x/dw &sum`) |

In gdb, `break halt` and `continue` stop a program at its last instruction, the loop
`halt: j halt`, where its result is ready.

## On bare metal

- **The assembler.** The programs are built with the GNU assembler and linker (`.s` files and the
  Makefile). The variables of `memory.s` and `sort-word-array.s` are reserved in the section
  `.bss`, the one that the linker puts in the RAM.
- **No operating system.** There is nothing to answer an `ecall`, so the programs make no system
  calls. A program that prints a character stores it into the terminal's register at
  `0xFFFF000C` itself; a program that works out a number leaves it in a register or in RAM; and
  every program that finishes ends in the loop `halt: j halt`. The keyboard's control register
  (RCR) is at `0xFFFF0004` and its data register (RDR) at `0xFFFF0008`. The terminal is always
  ready and has no control register.
- **ROM and RAM.** The program and its constants (`.text` and `.data`) are in the ROM, from address
  0, and `.bss` is in the RAM, from `0x00100000` (`logisim.lds` says so). The RAM has no
  starting values, so a program that changes its data puts the starting values there itself:
  `memory.s` stores 1 into `A` before it adds 5, and `sort-word-array.s` copies its array from the
  ROM (`Ainit`) into the RAM (`A`) before it sorts it.

`./test.sh` builds every program and checks each one without a window: what it prints in text
mode, and, with gdb, its registers and memory when it reaches `halt`.
