#!/bin/bash
# Test of interrupt_kbd.s in Logisim's text mode, by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
#   ./test.sh
#
# Runs the program with make run, types characters into the computer's keyboard and checks that
# they come back on the terminal. Then it runs the program with make debug and looks at it with
# gdb: mcause, mepc, mip and mstatus in the interrupt handler, the right digit's register, which
# must go on changing while characters are typed, and the registers that the handler saves and
# restores. It prints one PASS or FAIL line per check, and its exit status is 1 if any check
# failed. No window is opened.
#
# Environment: LOGISIM_JAR (default: the jar in the supplement's top folder, where make logisim
# puts it), GDB (default: gdb-multiarch, or another RISC-V gdb that is installed), GDB_PORT
# (default 3333). It needs Python 3 with the pexpect library.

HERE=$(cd "$(dirname "$0")" && pwd)
LOGISIM_JAR=${LOGISIM_JAR:-$HERE/../logisim-evolution-ucd-5.0.10-all.jar}
if [ ! -f "$LOGISIM_JAR" ]; then
    echo "test.sh: no Logisim jar at $LOGISIM_JAR (make logisim fetches it, or set LOGISIM_JAR)"
    exit 2
fi
LOGISIM_JAR=$(realpath "$LOGISIM_JAR")
GDB=${GDB:-$(command -v gdb-multiarch || command -v riscv64-elf-gdb || command -v riscv64-unknown-elf-gdb || echo gdb)}
GDB_PORT=${GDB_PORT:-3333}

python3 -I - "$HERE" "$LOGISIM_JAR" "$GDB" "$GDB_PORT" <<'PYEOF'
import os, re, subprocess, sys, time
import pexpect

HERE, JAR, GDB = sys.argv[1:4]
PORT = int(sys.argv[4])
ENV = dict(os.environ); ENV.pop("DISPLAY", None)        # nothing here may open a window
TIMEOUT = 60                                            # seconds for any one wait
failed = 0

def check(ok, text):
    global failed
    print(("PASS  " if ok else "FAIL  ") + text, flush=True)
    failed += not ok

def stop(*children):
    """Ctrl-C, as a reader would; then whatever is left, by process group."""
    for child in children:
        if child is None: continue
        if child.isalive():
            child.sendintr()
            for _ in range(20):
                if not child.isalive(): break
                time.sleep(0.25)
        try: os.killpg(child.pid, 9)
        except OSError: pass
        child.close(force=True)

def started(sim):
    """Waits for the last line that make prints, the simulator's command line, and for what Java
    itself prints when it is given options in the environment; the program's output comes next."""
    sim.expect(r"--tty raw\r?\n")
    for name in ("JAVA_TOOL_OPTIONS", "_JAVA_OPTIONS"):
        if ENV.get(name): sim.expect(r"Picked up %s:[^\n]*\n" % name)

def make(target):
    """make run or make debug in a pseudo-terminal, like a reader's terminal."""
    sim = pexpect.spawn("make", [target, "LOGISIM_JAR=" + JAR, "GDB_PORT=%d" % PORT], cwd=HERE, env=ENV,
                        encoding="utf-8", codec_errors="replace", timeout=TIMEOUT)
    sim.setecho(False)      # the pseudo-terminal must not echo: what comes back is the program's doing
    started(sim)
    return sim

def read(sim, seconds):
    """What the program prints in that time."""
    text = ""
    end = time.time() + seconds
    while time.time() < end:
        try: text += sim.read_nonblocking(1000, timeout=0.25)
        except pexpect.TIMEOUT: pass
        except pexpect.EOF: break
    return text

def echo(sim, text):
    """Types the text and returns what comes back: it waits for as many characters, then a little more."""
    sim.send(text)
    back = ""
    end = time.time() + TIMEOUT
    while len(back) < len(text) and time.time() < end:
        back += read(sim, 0.25)
    return back + read(sim, 0.5)

def listening():
    """Waits until the CPU's GDB server listens on the port."""
    for _ in range(4 * TIMEOUT):
        r = subprocess.run(["ss", "-ltn", "sport = :%d" % PORT], capture_output=True, text=True).stdout
        if ":%d" % PORT in r: return True
        time.sleep(0.25)
    return False

class Gdb:
    def __init__(self, elf):
        self.p = pexpect.spawn(GDB, ["-q", "-nx", elf], cwd=HERE, env=dict(ENV, TERM="dumb"), encoding="utf-8",
                               codec_errors="replace", timeout=TIMEOUT)
        self.p.expect_exact("(gdb) ")
        for line in ("set pagination off", "set confirm off", "set style enabled off", "set width 0",
                     "set architecture riscv:rv32", "set osabi none", "target remote localhost:%d" % PORT):
            self.cmd(line)
    def cmd(self, line, timeout=TIMEOUT):
        """A gdb command; returns what gdb printed, when its prompt is back."""
        self.p.sendline(line)
        self.p.expect_exact("(gdb) ", timeout=timeout)
        answer = self.p.before.replace("\r", "")
        return answer.split("\n", 1)[1] if "\n" in answer else ""
    def go(self):
        """continue, without waiting for the program to stop."""
        self.p.sendline("continue")
    def wait(self, timeout=TIMEOUT):
        """Waits for the program to stop (a breakpoint)."""
        self.p.expect_exact("(gdb) ", timeout=timeout)
    def halt(self):
        """Ctrl-C in gdb: stops the program where it is. A Ctrl-C that comes just after continue can be lost."""
        for attempt in range(6):
            self.p.sendintr()
            try:
                self.p.expect_exact("(gdb) ", timeout=10)
                return
            except pexpect.TIMEOUT:
                pass
        raise pexpect.TIMEOUT("gdb did not stop the program")
    def value(self, expression):
        m = re.search(r"= (\S+)", self.cmd("p/x " + expression))
        return int(m.group(1), 16) if m else None
    def word(self, address, size="w"):
        """The word (w), half word (h) or byte (b) of memory at the address."""
        return int(self.cmd("x/x%s %s" % (size, address)).split()[-1], 16)

# --- Part 1: make run. What is typed comes back from the interrupt handler.
sim = None
try:
    try:
        sim = make("run")
    except (pexpect.TIMEOUT, pexpect.EOF):
        pass
    check(sim is not None, "make run builds the program and starts the simulator")
    if sim is not None:
        # The simulator takes a few seconds to start. Type a full stop every second until one comes back.
        back = ""
        for _ in range(TIMEOUT):
            sim.send(".")
            back = read(sim, 1)
            if back: break
        back += read(sim, 2)
        check(back != "" and set(back) == {"."}, "make run: the program echoes a character once the simulator has started")
        one_by_one = "Interrupts"
        back = [echo(sim, ch) for ch in one_by_one]
        check(back == list(one_by_one), "make run: %d characters typed one at a time: each comes back, once (got %r)"
              % (len(one_by_one), "".join(back)))
        burst = "The quick brown fox jumps."
        back = echo(sim, burst)
        check(back == burst, "make run: %d characters typed at once come back in order, once (got %r)" % (len(burst), back))
finally:
    stop(sim)

# --- Part 2: make debug and gdb. The handler's CSRs, and the main loop that goes on running.
sim = gdb = None
DIGITS = {0x3f, 0x06, 0x5b, 0x4f}
try:
    try:
        sim = make("debug")
        ready = listening()
    except (pexpect.TIMEOUT, pexpect.EOF):
        ready = False
    check(ready, "make debug starts the simulator with the CPU's GDB server on port %d" % PORT)
    if ready:
        gdb = Gdb("keyboard-interrupt")
        loop, isr = gdb.value("(unsigned)&loop"), gdb.value("(unsigned)&isr")

        # the main loop alone: the right digit's register at 8 moments
        seen = set()
        for _ in range(8):
            gdb.go(); time.sleep(0.3); gdb.halt()
            seen.add(gdb.word("0xffff0010", "b"))
        check(len(seen) >= 2 and seen <= DIGITS,
              "before any key: the right digit's register changes (%s at 8 moments)" % ", ".join("0x%02x" % v for v in sorted(seen)))
        check(gdb.value("$mcause") == 0, "before any key: mcause is 0")

        # the handler uses s1 and the main program does not: give it a value to find again later
        gdb.cmd("set $s1 = 0x51515151")
        gdb.cmd("break isr")
        gdb.go()
        sim.send("k")
        try:
            gdb.wait()
            stopped = gdb.value("$pc") == isr
        except pexpect.TIMEOUT:
            gdb.halt(); stopped = False
        check(stopped, "a key typed while the main loop runs takes the CPU to isr")
        mcause, mepc, mip, mstatus = (gdb.value("$" + r) for r in ("mcause", "mepc", "mip", "mstatus"))
        check(mcause == 0x8000000b, "in the handler mcause is 0x8000000b (it is 0x%08x)" % mcause)
        check(loop <= mepc < isr, "in the handler mepc is in the main loop (0x%x; the loop is 0x%x to 0x%x)" % (mepc, loop, isr - 4))
        check(mip & 0x800 == 0x800, "in the handler mip has bit 11, the machine external interrupt (mip is 0x%x)" % mip)
        check(mstatus & 0x88 == 0x80, "in the handler mstatus has MIE 0 and MPIE 1 (mstatus is 0x%x)" % mstatus)
        rcr = gdb.word("0xffff0004")
        check(rcr == 3, "the keyboard's control register reads 3: a character waits and its interrupt is enabled (it reads %d)" % rcr)
        gdb.cmd("delete")
        gdb.go()
        back = read(sim, 2)
        check(back == "k", "the handler sends the character to the terminal (got %r)" % back)

        # 40 characters in 8 groups; after each group gdb stops the program where it is
        text = "Forty characters come back from the isr."
        back = ""
        seen = set(); kept = 0; samples = 0; outside = 0
        for i in range(0, len(text), 5):
            back += echo(sim, text[i:i + 5])
            gdb.halt()
            pc = gdb.value("$pc")
            seen.add(gdb.word("0xffff0010", "b"))
            if loop <= pc < isr:
                samples += 1
                kept += (gdb.value("$s0") == 0xffff0010 and gdb.value("$t1") == 2 and gdb.value("$s1") == 0x51515151)
            else:
                outside += 1
            gdb.go()
        check(back == text, "%d characters typed while gdb lets the program run come back, each once (got %r)" % (len(text), back))
        check(len(seen) >= 2 and seen <= DIGITS,
              "meanwhile the right digit's register goes on changing (%s at 8 moments)" % ", ".join("0x%02x" % v for v in sorted(seen)))
        check(samples >= 6 and kept == samples,
              "after the interrupts s0, t1 and s1 hold what they held before (0xffff0010, 2, 0x51515151) at %d of %d stops in the main loop"
              % (kept, samples))
        time.sleep(0.5); gdb.halt()
        mcause = gdb.value("$mcause")
        check(mcause == 0x8000000b, "mcause is still 0x8000000b (it is 0x%08x)" % mcause)
        gdb.cmd("detach")
finally:
    stop(gdb.p if gdb else None, sim)
print("all passed" if not failed else "%d failed" % failed)
sys.exit(1 if failed else 0)
PYEOF
