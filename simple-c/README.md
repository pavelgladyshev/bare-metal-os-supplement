# simple-c: a first program in C

`main.c` prints `Hello world!` on the computer's terminal with a `putchar()` and a `puts()` of
its own, which store characters into the terminal's register at `0xFFFF000C`: there is no
operating system and no C library underneath. `crt0.S` is what runs first: it sets the stack
pointer to the top of the RAM, calls `main()`, and loops for ever when `main()` returns.
`logisim.lds`, the linker script, puts the program into the ROM and its variables into the RAM.

```bash
make            # build the program: the ELF file simple-c, the listing simple-c.asm, the ROM image simple-c-rom.txt
make run        # run it in the terminal (Ctrl-C stops it)
make gui        # run it in Logisim's window; start the clock with Simulate, Auto-Tick Enabled (Ctrl-K)
make debug      # as make run, but the CPU waits for a debugger; then, in a second terminal:
make gdb        # gdb, connected to the CPU: break main, continue, step
make list       # the program's instructions and their addresses, beside the C source
```

The program runs in the ROM of a copy of the computer (`../computer/computer.circ`) that these
commands make in the folder `build`.
