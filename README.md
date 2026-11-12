# Supplement to *Operating Systems from the Bare Metal Up*

Example programs and circuits for the book *Operating Systems from the Bare Metal Up: building
logOS on a simulated RISC-V computer* by Pavel Gladyshev. The operating system itself, logOS,
is in [its own repository](https://github.com/pavelgladyshev/logos).

| Folder | Runs in | Chapter |
| --- | --- | --- |
| `rars/` (`example1.asm`, `riscv-*.asm`) | RARS | 2 |
| `simple-asm/` | Logisim | 2 |
| `simple-c/` | Logisim | 3, 4 |
| `pong/blocking/`, `pong/fsm/`, `pong/coroutines/` | Logisim | 3, 4, 11 |
| `rars/polled_kbd.asm`, `rars/interrupt_kbd.asm` | RARS | 12 |
| `pong_interrupt/` | Logisim | 12 |
| `rars/multitasking.asm` | RARS | 13 |
| `smp-simple-assembly/`, `smp-boxes/`, `smp-boxes-synchronised/` | QEMU | 21 |

## Setting up

The tools are those of logOS: clone it and run its `setup.sh`, which installs the RISC-V
compiler and Java and fetches Logisim Evolution UCD (macOS with Homebrew, Ubuntu or Debian,
Windows with Ubuntu on WSL 2). The multiprocessor examples also need QEMU
(`sudo apt install qemu-system-misc`, or `brew install qemu`), and the RARS programs need the
[modified RARS](https://github.com/pavelgladyshev/COMP20180-rars).

## Building and running

```bash
make            # builds every project, with the RISC-V compiler this computer has
make check      # says which tools were found
```

Each project also builds on its own, with `make` in its folder. The projects' Makefiles name
Ubuntu's compiler; on a Mac type `make RISCV_TOOL_PREFIX=riscv64-elf-` there.

- **Logisim projects** make a ROM image (`*.txt`): open the project's circuit in Logisim
  Evolution UCD, right-click the ROM, choose *Load Image...* and select it.
- **QEMU projects**: `make qemu` runs the program on QEMU's `virt` machine with three harts
  (`make qemu CPUS=8` for eight). Ctrl-A, then x, leaves QEMU.
- **RARS programs**: open the `.asm` file in RARS, assemble and run.

## Licence

The example programs, build files, circuits and documentation are licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); the set-up scripts are under the MIT
licence; three files adapted from xv6 keep its MIT licence. See `LICENSE`.
