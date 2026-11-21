# Preemptive multitasking

`multitasking.s` is the program of chapter 13, *Preemptive multitasking*: two processes, each an
endless loop that writes the digits 0, 1, 2, 3 to its own seven-segment digit (`process_1` the
right one, `0xFFFF0010`; `process_2` the left one, `0xFFFF0011`), and a timer interrupt that
takes the CPU from one and gives it to the other. `main` fills in the two trap frames, asks the
Timer for an interrupt `TIME_SLICE` clock cycles from now (`mtimecmp` = `mtime` + `TIME_SLICE`),
enables the machine timer interrupt (`mie` = `0x80`, bit 7) and interrupts as a whole (bit 3 of
`mstatus`), and jumps to `process_1`. `trap_handler` saves `s0` to `s3` and the pc of the
interrupted process in its trap frame, sets the next alarm in the same way, follows the frame's
`next` field, restores the other process from its frame and returns with `mret`.

```bash
make gui        # Logisim's window: Simulate, Auto-Tick Enabled (Ctrl-K)
make debug      # text mode, the CPU waits for a debugger; then, in a second terminal: make gdb
make list       # the instructions and their addresses (trap_handler is at 0x100)
./test.sh       # checks the switching with gdb, without a window (about a minute)
```

What to look at in the window:

- the two digits, which take turns: with `TIME_SLICE` = 2000 and the window's clock of about
  4096 cycles a second, each process runs for about half a second while the other's digit stands still;
- the Timer, which shows `mtime` and `mtimecmp`;
- the panel of machine CSRs below the registers: `mtvec` = `0x00000100`, `mie` = `0x00000080`,
  `mcause` = `0x80000007` ("interrupt 7: M timer") and `mepc`, the place where the last process
  was stopped (`0xa8` to `0xd0` in `process_1`, `0xd4` to `0xfc` in `process_2`).

In gdb, `break trap_handler` and `continue` stop the program at every switch, and
`x/13xw 0x00100000` shows `current_process_trap_frame` and the two trap frames (pc, `s0` to `s3`,
`next`). `mtime` counts on while gdb holds the CPU, so when you continue after a stop inside a process
the next interrupt comes at once. `TIME_SLICE` is set at the top of the program.
