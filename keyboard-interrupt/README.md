# An interrupt-driven keyboard

`interrupt_kbd.s` is the second program of chapter 13, *Computer architecture and interrupts*:
the two jobs of `../keyboard-polled`, with the keyboard served by an interrupt. `main` puts the
address of `isr` into `mtvec`, enables the machine external interrupt (`mie` = `0x800`, bit 11)
and interrupts as a whole (`mstatus` = 8, bit 3, MIE), and sets the interrupt enable of the
keyboard (bit 1 of its control register at `0xFFFF0004`). Its loop then writes the digits 0, 1,
2, 3 to the right seven-segment digit and never looks at the keyboard. `isr` saves `t0`, `t1`,
`s0`, `s1` and `mepc` in `frame`, which is in the RAM at `0x00100000`, reads the character from
`0xFFFF0008`, which takes the keyboard's request away, sends it to the terminal (`0xFFFF000C`),
restores the registers and returns with `mret`.

```bash
make run        # type: each character comes back (Ctrl-C stops it)
make gui        # Logisim's window: Simulate, Auto-Tick Enabled (Ctrl-K), then click the keyboard and type
make debug      # as make run, but the CPU waits for a debugger; then, in a second terminal: make gdb
./test.sh       # checks the echo, and with gdb the CSRs in the handler and the registers it must keep
```

What to look at in the window, in the panel of machine CSRs below the registers:

- before any key: `mtvec` = `0x0000005c`, the address of `isr`; `mie` = `0x00000800`; `mstatus`
  with MIE=1; `mcause` = 0 ("no trap yet");
- after a key: `mcause` = `0x8000000b` ("interrupt 11: M external"); `mepc`, the address in the
  loop (`0x38` to `0x58`) at which the key found the program; `mscratch`, the value of `t0` that
  the handler kept there, which is one of the digit codes.

In gdb, `break isr` and `continue`, then type a key in the first terminal: the program stops at
the handler's first instruction with `mcause` = `0x8000000b`, `mip` = `0x800` and MIE=0, MPIE=1
in `mstatus` (`info registers mcause mepc mip mstatus`). `stepi` goes through the handler, and
`x/5xw &frame` shows the saved registers.
