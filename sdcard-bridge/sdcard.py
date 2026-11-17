#!/usr/bin/env python3
"""Read and write the microSD card in a Tang Nano 20K that runs the sdbridge bitstream.

    sdcard.py [--port /dev/ttyUSB1] ping
    sdcard.py [--port ...] read  IMAGE [BLOCKS]     copy the card's first BLOCKS blocks (default 1024) to IMAGE
    sdcard.py [--port ...] write IMAGE              copy IMAGE to the card from its block 0, then check it
    sdcard.py [--port ...] dump  BLOCK              show one block in hex

The card is written raw, block n of the image becoming block n of the card, as logOS's Block Storage
expects. Only blocks that differ from what the card already holds are written. The port is found by
itself on Linux (the board's second serial interface) and on macOS; --port or SDCARD_PORT chooses
another. No packages beyond Python's own are needed.
"""
import glob, os, select, struct, sys, termios, time

BLOCK = 512


class Bridge:
    def __init__(self, port=None):
        self.port = port or os.environ.get("SDCARD_PORT") or find_port()
        self.fd = os.open(self.port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        a = termios.tcgetattr(self.fd)
        a[0] = a[1] = a[3] = 0
        a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
        a[4] = a[5] = termios.B115200
        termios.tcsetattr(self.fd, termios.TCSANOW, a)
        self.resync()

    def _read(self, n, timeout=2.0):
        out, end = bytearray(), time.time() + timeout
        while len(out) < n and time.time() < end:
            if select.select([self.fd], [], [], 0.05)[0]:
                out += os.read(self.fd, n - len(out))
        return bytes(out)

    def _write(self, data):
        view = memoryview(data)
        while view:
            select.select([], [self.fd], [], 1.0)
            view = view[os.write(self.fd, view):]

    def resync(self):
        """Bring the board back to waiting for a command, and check that it is there."""
        for attempt in range(3):
            time.sleep(0.6 if attempt else 0.05)           # an unfinished request ends after half a second
            termios.tcflush(self.fd, termios.TCIOFLUSH)
            while select.select([self.fd], [], [], 0.05)[0]:
                os.read(self.fd, 4096)
            self._write(b"P")
            if self._read(4, 1.0) == b"SDB1":
                return
        sys.exit(f"no sdbridge on {self.port} (is the bitstream loaded? make load)")

    def read(self, n):
        for attempt in range(4):
            self._write(b"R" + struct.pack("<I", n))
            status = self._read(1, 5.0)
            if status == b"E":
                raise IOError(f"the card failed to read block {n} (is there a card?)")
            if status == b"K":
                reply = self._read(BLOCK + 2, 5.0)
                if len(reply) == BLOCK + 2 and sum(reply[:BLOCK]) & 0xFFFF == struct.unpack("<H", reply[BLOCK:])[0]:
                    return reply[:BLOCK]
            self.resync()
        raise IOError(f"block {n}: no good reply after four tries")

    def write(self, n, data):
        assert len(data) == BLOCK
        for attempt in range(4):
            self._write(b"W" + struct.pack("<I", n) + data + struct.pack("<H", sum(data) & 0xFFFF))
            status = self._read(1, 5.0)
            if status == b"K":
                return
            if status == b"E":
                raise IOError(f"the card failed to write block {n}")
            self.resync()                                    # 'C' (damaged on the way) or nothing
        raise IOError(f"block {n}: not written after four tries")


def find_port():
    found = (sorted(glob.glob("/dev/serial/by-id/*SIPEED*if01*")) or sorted(glob.glob("/dev/cu.usbserial-*1"))
             or sorted(glob.glob("/dev/ttyUSB1")))
    if not found:
        sys.exit("no Tang Nano 20K serial port found; give one with --port")
    return found[0]


def progress(i, total, start, what):
    rate = (i + 1) / max(time.time() - start, 1e-6)
    sys.stderr.write(f"\r{what} {i + 1}/{total} blocks, {rate:.0f} blocks/s ")
    sys.stderr.flush()


def main(argv):
    port = None
    if len(argv) > 2 and argv[1] == "--port":
        port, argv = argv[2], argv[:1] + argv[3:]
    if len(argv) < 2 or argv[1] not in ("ping", "read", "write", "dump"):
        sys.exit(__doc__)
    bridge = Bridge(port)
    cmd = argv[1]
    if cmd == "ping":
        print(f"sdbridge on {bridge.port}; block 0 of the card starts {bridge.read(0)[:8].hex(' ')}")
    elif cmd == "dump":
        data = bridge.read(int(argv[2], 0))
        for off in range(0, BLOCK, 16):
            print(f"{off:04x}  " + data[off:off + 16].hex(" "))
    elif cmd == "read":
        total, start = (int(argv[3]) if len(argv) > 3 else 1024), time.time()
        with open(argv[2], "wb") as f:
            for i in range(total):
                f.write(bridge.read(i))
                progress(i, total, start, "read")
        sys.stderr.write("\n")
    elif cmd == "write":
        image = open(argv[2], "rb").read()
        if len(image) % BLOCK:
            image += bytes(BLOCK - len(image) % BLOCK)
        total, start, written = len(image) // BLOCK, time.time(), 0
        for i in range(total):
            want = image[i * BLOCK:(i + 1) * BLOCK]
            if bridge.read(i) != want:
                bridge.write(i, want)
                written += 1
                if bridge.read(i) != want:
                    sys.exit(f"\nblock {i} reads back differently after writing")
            progress(i, total, start, "write")
        sys.stderr.write(f"\n{written} of {total} blocks written, all {total} checked\n")


if __name__ == "__main__":
    main(sys.argv)
