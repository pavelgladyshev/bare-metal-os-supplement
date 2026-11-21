# The smallest project

`main.s` prints `Hi` on the computer's terminal and stops in a loop. With it are the two files
that every Logisim project of the supplement has: the `Makefile` and the linker script
`logisim.lds`, which puts the program and its constants into the ROM, from address 0, and its
variables into the RAM, from `0x00100000`.

```bash
make            # build the program: the ELF file template, the listing template.asm, the ROM image template-rom.txt
make run        # run it in the terminal (Ctrl-C stops it)
make gui        # run it in Logisim's window; start the clock with Simulate, Auto-Tick Enabled (Ctrl-K)
make debug      # as make run, but the CPU waits for a debugger; then, in a second terminal:
make gdb        # gdb, connected to the CPU: try stepi, info registers, x/4i $pc
make list       # the program's instructions and their addresses, beside the source
```

## A project of your own

Copy this folder beside the others, and change the part of the `Makefile` that is headed
"Application-specific detail": the name of the program (`EXECUTABLE`), its object files, one for
each source file (`OBJECT_FILES`), and its header files. `CSR_PANEL = machine` adds the
processor's control and status registers to what the window shows, which a program with
interrupts wants; such a program also needs `RISCV_ISA = rv32im_zicsr` there.

Leave the rest of the `Makefile`, from "Common part" to the end, as it is: it is the same in
every project, and `make check-template` in the supplement's top folder says so.
