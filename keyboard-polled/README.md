# A polled keyboard

`polled_kbd.s` is the first program of chapter 13, *Computer architecture and interrupts*: one
loop that does two jobs. On every trip it reads the keyboard's control register (`0xFFFF0004`);
if a character is waiting, it reads it from the data register (`0xFFFF0008`) and sends it to the
terminal (`0xFFFF000C`); then it writes the next of the digits 0, 1, 2, 3 to the right
seven-segment digit (`0xFFFF0010`). It uses no interrupt.

```bash
make run        # type: each character comes back (Ctrl-C stops it)
make gui        # Logisim's window: Simulate, Auto-Tick Enabled (Ctrl-K), then click the keyboard and type
make debug      # as make run, but the CPU waits for a debugger; then, in a second terminal: make gdb
./test.sh       # checks the echo in text mode, without a window
```

What to look at in the window:

- the terminal, which shows what you type, and the right digit, which goes through 0, 1, 2, 3
  for as long as the program runs;
- the CPU's PC, which goes round the loop from `0x28` to `0x4c`; `t0` (`x5`), which holds what
  was read from the control register and then the digit's code; `s5` (`x21`), the index 0 to 3;
- the panel of machine CSRs below the registers, where nothing ever changes: `mie` is 0,
  `mstatus` has MIE=0 and `mcause` stays 0 (the panel says "no trap yet").

The digit codes are in `.rodata`, which is in the ROM. The keyboard keeps up to 32 characters
that the program has not read yet.
