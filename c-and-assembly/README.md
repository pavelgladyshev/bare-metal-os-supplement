# c-and-assembly: a C program that calls a function written in assembly language

`main.c` prints a line on the computer's terminal by calling `print()`, and `print()` is not
written in C: it is the assembly routine in `print.s`. Three things make that work. `print.s` is
a source file of its own, and its object file, `print.o`, is in the list `OBJECT_FILES` of the
Makefile; the label `print` is declared `.globl`, so that the linker can find it; and the routine
follows the calling convention: it takes its argument, the address of the string, from `a0`, and
uses only registers that a function may change. `lib.h` declares `print()` for the C compiler.
`crt0.S` and `logisim.lds` are those of `simple-c`.

```bash
make            # build the program: the ELF file c-and-assembly, the listing c-and-assembly.asm, the ROM image c-and-assembly-rom.txt
make run        # run it in the terminal (Ctrl-C stops it)
make gui        # run it in Logisim's window; start the clock with Simulate, Auto-Tick Enabled (Ctrl-K)
make debug      # as make run, but the CPU waits for a debugger; then, in a second terminal:
make gdb        # gdb, connected to the CPU: break print, continue, stepi
make list       # the program's instructions and their addresses, beside the source
```

The program runs in the ROM of a copy of the computer (`../computer/computer.circ`) that these
commands make in the folder `build`.
