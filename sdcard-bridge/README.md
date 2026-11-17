# sdcard-bridge: the Tang Nano 20K as a microSD card reader

This bitstream turns a Sipeed Tang Nano 20K into a reader and writer for the microSD card in its TF slot.
Your computer reaches the card through the board's USB serial port, so it needs no card reader. The card
is driven by `riscvSdBlockStorage`, the same module that Logisim-evolution (UCD edition) uses for the
Block Storage component when it puts `computer.circ` on this board. As a result, a card written here is
exactly what logOS on the board will read.

## Use

```sh
make            # build sdbridge.fs (Gowin open-source toolchain in ~/gowin, as Logisim's FPGA flow uses)
make load       # load it into the FPGA, until the board is unplugged
./sdcard.py ping
```

The serial port is the board's second interface: `/dev/ttyUSB1` on Linux, or
`/dev/serial/by-id/usb-SIPEED_USB_Debugger_*-if01-port0`, and `/dev/cu.usbserial-…1` on macOS.

With logOS (any of the three branches), fstool and logosfs accept the serial port wherever they take a
disk image:

```sh
make fs-image DISK=/dev/ttyUSB1          # a fresh logOS disk, written straight to the card
fstool/fstool ls /dev/ttyUSB1 /bin
fstool/fstool add /dev/ttyUSB1 /etc/notes.txt notes.txt
fstool/logosfs /dev/ttyUSB1 mnt          # mount the card (make logosfs first)
```

Then load the computer (`computer.circ` through Logisim's FPGA flow) back into the board, and logOS boots
from the card.

`sdcard.py` copies whole images:

```sh
./sdcard.py read  backup.bin 1024        # the card's first 1024 blocks into a file
./sdcard.py write block_storage.bin      # an image onto the card (only changed blocks), checked
./sdcard.py dump  0                      # one block in hex
```

## Speed

The link is 115200 baud, so it moves about 21 blocks (10 KB) a second. A whole 1024-block logOS disk takes
about a minute to write with `sdcard.py`, or 2½ minutes with `make fs-image DISK=…`, which re-reads the file
system for each file it adds. fstool and logosfs keep every block that they have read, so each block crosses
the line once per run.

## Protocol

Serial settings are 115200 baud, 8N1. Each request starts with a command byte, and numbers are
little-endian. `sum` is the 16-bit sum of the 512 data bytes.

| request | reply |
|---|---|
| `P` | `SDB1` |
| `R` block[4] | `K` data[512] sum[2], or `E` |
| `W` block[4] data[512] sum[2] | `K`, `E`, or `C` |

`E` means the card failed, or there is no card. `C` means the data arrived damaged, and nothing was
written. A request left unfinished is dropped after half a second, and the board then waits for a new
command byte.

LEDs (counting from the board's edge): LED0 lit while the card is working, LED1 lit after a failed
command, LED5 blinks while the bridge runs.

## Files

- `rtl/sdbridge.v`: the bridge (serial port, command sequencer, one-block buffer)
- `rtl/riscvSdBlockStorage.v`: the card controller, from Logisim-evolution (UCD edition)
- `sim/tb_sdbridge.v`, `sim/sd_card_model.v`: simulation with a model card (`make sim`, needs iverilog)
- `tangnano20k.cst`: pins
- `sdcard.py`: the host tool (Python 3, no packages)
