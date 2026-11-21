# The race cured: disabling interrupts

`multitasking_racing_synchronised.s` is the second program of chapter 17, *Synchronisation*. It
is `../multitasking-racing/multitasking_racing.s` with two instructions more in each process:
`csrci mstatus,8` before the loop that prints a message, which clears MIE (bit 3 of `mstatus`)
and so disables interrupts, and `csrsi mstatus,8` after it, which enables them again. The
printing of a message has become a critical section: the timer may ask for an interrupt in the
middle of it, but the CPU takes the interrupt only when the message is finished.

```bash
make run        # whole messages only (Ctrl-C stops it)
make gui        # Logisim's window: Simulate, Auto-Tick Enabled (Ctrl-K)
make debug      # as make run, but the CPU waits for a debugger; then, in a second terminal: make gdb
./test.sh       # checks in text mode that every line is one whole message
```

This is how the output of `make run` begins, and how it goes on:

```
My funny bone has a fracture.
It's not rocket surgery.
My funny bone has a fracture.
It's not rocket surgery.
```

The messages take turns because printing one takes longer than the 70 clock cycles of
`TIME_SLICE`: the timer's request is always waiting when a process enables interrupts again, and
the switch follows at once. In the window, the panel of machine CSRs shows it: while a message
is printed `mstatus` has MIE=0, and `mip` becomes `0x00000080` when the Timer's request arrives
and stays so until the end of the message.
