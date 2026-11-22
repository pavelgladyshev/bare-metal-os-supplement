# A race: two processes, one terminal

`multitasking_racing.s` is the first program of chapter 18, *Synchronisation*. It is
`../multitasking/multitasking.s` with two other processes: each prints its message on the
terminal (`0xFFFF000C`), one character at a time, for ever. `process_1` prints
`My funny bone has a fracture.` and `process_2` prints `It's not rocket surgery.` The timer
interrupt comes every 70 clock cycles (`TIME_SLICE`, at the top of the program), and the handler
gives the CPU to the other process wherever the first has got to in its message.

```bash
make run        # the two messages, mixed (Ctrl-C stops it)
make gui        # Logisim's window: Simulate, Auto-Tick Enabled (Ctrl-K)
make debug      # as make run, but the CPU waits for a debugger; then, in a second terminal: make gdb
./test.sh       # checks in text mode that the messages are mixed and that no character is lost
```

This is how the output of `make run` begins:

```
My funnIt's y bonnot re hasocket a fra surgctureery.
.
MyIt's funn not ry bonockete has surg a fraery.
ctureIt's.
My not  funnrockety bon surge hasery.
 a fraIt'scture not .
```

Each process gets four to six characters out before the next interrupt. No character is lost: the
characters of each message are all there and in order, with the other message's between them.
In the window, the panel of machine CSRs shows `mcause` = `0x80000007` and, in `mepc`, the
instruction at which the last process was stopped (`0xa8` to `0xc8` in `process_1`, `0xcc` to
`0xec` in `process_2`). With a larger `TIME_SLICE` the pieces are longer.
