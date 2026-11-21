# simple-asm: a first program in assembly language

`simple.s` writes `Hi` to the computer's terminal, a character at a time, by storing each
character into the terminal's register at `0xFFFF000C`. Then it stops in a loop.

```bash
make            # build the program: the ELF file simple-asm, the listing simple-asm.asm, the ROM image simple-asm-rom.txt
make run        # run it in the terminal (Ctrl-C stops it)
make gui        # run it in Logisim's window; start the clock with Simulate, Auto-Tick Enabled (Ctrl-K)
make debug      # as make run, but the CPU waits for a debugger; then, in a second terminal:
make gdb        # gdb, connected to the CPU, with the program's symbols
make list       # the program's instructions and their addresses, beside the source
```

The program runs in the ROM of a copy of the computer (`../computer/computer.circ`) that these
commands make in the folder `build`. Running without the window is much faster, because Logisim
does not redraw the circuit several times a second.
