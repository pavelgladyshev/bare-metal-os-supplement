# Supplement to *Operating Systems from the Bare Metal Up*

Example programs and circuits for the book *Operating Systems from the Bare Metal Up: building
logOS on a simulated RISC-V computer* by Pavel Gladyshev. The operating system itself, logOS,
is in [its own repository](https://github.com/pavelgladyshev/logos).

| Folder | Runs in | Chapter |
| --- | --- | --- |
| `computer/` (the simulated computer, `computer.circ`; its `README.md` is the reference: memory map, device registers, interrupts) | Logisim | Appendix B |
| `template/` (the smallest program, with the Makefile that every Logisim project shares; a project of your own starts as a copy of it) | Logisim | |
| `assembly/` (`example1.s`, `memory.s`, `led.s`, `echo.s`, `max.s`, `looping.s`, `subroutine.s`, `sort-word-array.s`) | Logisim | 2 |
| `simple-asm/` | Logisim | 2 |
| `simple-c/` | Logisim | 3, 4 |
| `pong/blocking/`, `pong/fsm/`, `pong/coroutines/` | Logisim | 3, 4, 11 |
| `keyboard-polled/`, `keyboard-interrupt/` | Logisim | 12 |
| `pong_interrupt/` | Logisim | 12 |
| `multitasking/` | Logisim | 13 |
| `multitasking-racing/`, `multitasking-synchronised/` | Logisim | 17 |
| `smp-simple-assembly/`, `smp-boxes/`, `smp-boxes-synchronised/` | QEMU | 21 |
| `smp-counter-litmus/` (`counter`, `litmus`: two harts, RV32IMA) | QEMU | 21 |
| `logos-programs/` (the book's illustration programs for logOS; see its `README.md`) | logOS in Logisim | 14, 15, 17, 18, 20 |
| `tools/run_logisim.py` (types commands from a file into logOS; see below) | Logisim | Appendix D |
| `sdcard-bridge/` (a Tang Nano 20K as a reader and writer for its microSD card; see its `README.md`) | Tang Nano 20K | Appendix E |

## Setting up

The tools are those of logOS: clone it and run its `setup.sh`, which installs the RISC-V
compiler and Java (macOS with Homebrew, Ubuntu or Debian, Windows with Ubuntu on WSL 2).
Logisim Evolution UCD, version 5.0.10, is fetched into this folder by the first `make run` or
`make gui` of a Logisim project, or by `make logisim` there. The debugger is gdb for RISC-V:
`gdb-multiarch` on Ubuntu, `riscv64-elf-gdb` from Homebrew. The multiprocessor examples also
need QEMU (`sudo apt install qemu-system-misc`, or `brew install qemu`).

## Building and running

```bash
make            # builds every project, with the RISC-V compiler this computer has
make check      # says which tools were found
```

Each project also builds on its own, with `make` in its folder. The projects' Makefiles name
Ubuntu's compiler; on a Mac type `make RISCV_TOOL_PREFIX=riscv64-elf-` there.

- **Logisim projects** all run in the same way. In a project's folder:

  ```bash
  make            # build the program: an ELF file, a listing and the ROM image
  make run        # run it in the terminal, which becomes the computer's terminal and keyboard (Ctrl-C stops it)
  make gui        # run it in Logisim's window; start the clock with Simulate, Auto-Tick Enabled (Ctrl-K)
  make debug      # as make run, but the CPU waits for a debugger; then, in a second terminal:
  make gdb        # gdb, connected to the CPU, with the program's symbols
  make list       # the program's instructions and their addresses, beside the source
  ```

  Each of these puts the program into the ROM of a copy of the circuit, in the project's `build`
  folder (`tools/mkcircuit.py` does it): nothing is loaded by hand, and the circuit itself never
  changes. `make gui-debug` is `make debug` in the window. All the projects run on the one
  computer, `computer/computer.circ`, except the Pong games, whose circuits have a graphical
  display and less memory (`pong/pong.circ`, `pong_interrupt/pong_interrupt.circ`). In `assembly/`
  the variable `PROG` names the program: `make PROG=max gui`.
- **QEMU projects**: `make qemu` runs the program on QEMU's `virt` machine with three harts
  (`make qemu CPUS=8` for eight). Ctrl-A, then x, leaves QEMU. In `smp-counter-litmus/` the targets are
  `make run-counter` and `make run-litmus`.
- **Programs for logOS** (`logos-programs/`): copy one into a logOS tree and add its name to
  `USER_PROGS` in the tree's Makefile, as `logos-programs/README.md` explains.
- **`tools/run_logisim.py`** boots a logOS tree in Logisim without its window, types the commands
  of a file into the logOS shell and prints what comes back:
  `python3 tools/run_logisim.py <tree> <scratch folder> <command file>`. It needs the `pexpect`
  library (`pip install pexpect`) and looks for the Logisim jar in the tree, where logOS's
  `setup.sh` puts it; `--jar` or the environment variable `LOGISIM_JAR` names another. The
  comment at the top of the file has the details.
- **`sdcard-bridge/`** is an FPGA bitstream that lets your computer read and write the microSD card in
  a Tang Nano 20K over the board's USB serial port. logOS's fstool and logosfs take the serial port in
  place of a disk image: `make fs-image DISK=/dev/ttyUSB1` puts a fresh logOS disk on the card, and
  `fstool/logosfs /dev/ttyUSB1 mnt` mounts it. Its `README.md` has the details.

## Licence

The example programs, build files, circuits and documentation are licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); the set-up scripts are under the MIT
licence; three files adapted from xv6 keep its MIT licence. See `LICENSE`.
