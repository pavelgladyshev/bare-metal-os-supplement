#!/bin/bash
# Test of multitasking.s in Logisim's text mode, by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
#   ./test.sh
#
# Runs the program with make debug and looks at it with gdb, stopping it at trap_handler: the
# CSRs at the first timer interrupt and the trap frames that main has filled in; then, over 16
# interrupts, the saved program counters in the two trap frames and the two digits' registers,
# which must all keep changing; then a register of each process that the handler uses itself
# (s2 and s3, given values with gdb), which must be found unchanged after 300 switches; and at
# last the timer interrupt when mtime, set with gdb just below 2^32, goes on into its high word.
# It prints one PASS or FAIL line per check, and its exit status is 1 if any check failed.
# No window is opened. It takes about a minute.
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

sim = gdb = None
DIGITS = {0x3f, 0x06, 0x5b, 0x4f}
SWITCHES = 300
hexes = lambda values: ", ".join("0x%x" % v for v in values)
try:
    try:
        sim = make("debug")
        ready = listening()
    except (pexpect.TIMEOUT, pexpect.EOF):
        ready = False
    check(ready, "make debug starts the simulator with the CPU's GDB server on port %d" % PORT)
    if ready:
        gdb = Gdb("multitasking")
        A = {name: gdb.value("(unsigned)&" + name) for name in
             ("process_1", "loop_1", "process_2", "loop_2", "trap_handler", "trap_frame_1", "trap_frame_2")}
        in_1 = lambda pc: A["process_1"] <= pc < A["process_2"]
        in_2 = lambda pc: A["process_2"] <= pc < A["trap_handler"]
        frame = lambda n: [gdb.word("(char *)&trap_frame_%d + %d" % (n, offset)) for offset in range(0, 24, 4)]
        current = lambda: gdb.word("&current_process_trap_frame")
        mtime = lambda: gdb.word("0x0200bffc") << 32 | gdb.word("0x0200bff8")

        # --- the first timer interrupt
        gdb.cmd("break trap_handler")
        gdb.cmd("continue")
        mcause, mepc, mip, mie, mstatus = (gdb.value("$" + r) for r in ("mcause", "mepc", "mip", "mie", "mstatus"))
        check(gdb.value("$pc") == A["trap_handler"], "the first timer interrupt takes the CPU to trap_handler")
        check(mcause == 0x80000007, "in the handler mcause is 0x80000007 (it is 0x%08x)" % mcause)
        check(in_1(mepc), "the first interrupt finds the CPU in process_1 (mepc is 0x%x)" % mepc)
        check(mip & 0x80 == 0x80 and mie == 0x80, "mip has bit 7, the machine timer interrupt, and mie is 0x80 (mip 0x%x, mie 0x%x)" % (mip, mie))
        check(mstatus & 0x88 == 0x80, "in the handler mstatus has MIE 0 and MPIE 1 (mstatus is 0x%x)" % mstatus)
        f1, f2 = frame(1), frame(2)
        check(current() == A["trap_frame_1"] and f1[0] == A["process_1"] and f1[5] == A["trap_frame_2"]
              and f2[0] == A["process_2"] and f2[5] == A["trap_frame_1"],
              "main has created the two processes: each trap frame has its process's first pc and the other frame's address, "
              "and trap_frame_1 is the current one")

        # --- 16 interrupts, seen at the handler's first instruction
        causes, mepcs, currents, pcs1, pcs2, right, left = [], [], [], [], [], [], []
        for i in range(16):
            if i: gdb.cmd("continue")
            causes.append(gdb.value("$mcause")); mepcs.append(gdb.value("$mepc")); currents.append(current())
            pcs1.append(frame(1)[0]); pcs2.append(frame(2)[0])
            both = gdb.word("0xffff0010", "h")
            right.append(both & 0xff); left.append(both >> 8)
        check(all(c == 0x80000007 for c in causes), "mcause is 0x80000007 at each of 16 interrupts")
        check(currents == [A["trap_frame_1"], A["trap_frame_2"]] * 8
              and all(in_1(pc) for pc in mepcs[0::2]) and all(in_2(pc) for pc in mepcs[1::2]),
              "the interrupts find process_1 and process_2 in turn (mepc: %s)" % hexes(mepcs))
        check(len(set(pcs1)) >= 3 and all(in_1(pc) for pc in pcs1),
              "the saved pc in trap_frame_1 keeps changing (%d different values at 16 interrupts: %s)" % (len(set(pcs1)), hexes(sorted(set(pcs1)))))
        check(len(set(pcs2)) >= 3 and all(in_2(pc) for pc in pcs2),
              "the saved pc in trap_frame_2 keeps changing (%d different values at 16 interrupts: %s)" % (len(set(pcs2)), hexes(sorted(set(pcs2)))))
        check(len(set(right)) >= 3 and set(right) <= DIGITS,
              "the right digit's register keeps changing (%s)" % hexes(sorted(set(right))))
        check(len(set(left) - {0}) >= 3 and set(left) <= DIGITS | {0},
              "the left digit's register keeps changing (%s)" % hexes(sorted(set(left))))

        # --- s2 and s3 of each process, which the handler uses for the timer, after many switches
        gdb.cmd("delete")
        gdb.cmd("tbreak loop_1"); gdb.cmd("continue")
        gdb.cmd("set $s2 = 0x11111111"); gdb.cmd("set $s3 = 0x13131313")
        gdb.cmd("tbreak loop_2"); gdb.cmd("continue")
        gdb.cmd("set $s2 = 0x22222222"); gdb.cmd("set $s3 = 0x23232323")
        number = re.search(r"Breakpoint (\d+)", gdb.cmd("break trap_handler")).group(1)
        gdb.cmd("ignore %s %d" % (number, SWITCHES - 1))
        try:
            gdb.cmd("continue", timeout=300)
            hits = int(re.search(r"already hit (\d+) time", gdb.cmd("info breakpoints")).group(1))
        except pexpect.TIMEOUT:
            gdb.halt(); hits = 0
        check(hits == SWITCHES, "gdb counts %d more timer interrupts (context switches)" % SWITCHES)
        gdb.cmd("delete")
        gdb.cmd("tbreak loop_1"); gdb.cmd("continue")
        s = [gdb.value("$s%d" % i) for i in (1, 2, 3)]
        check(s == [0xffff0010, 0x11111111, 0x13131313],
              "after them process_1 has its s1, s2 and s3 (0xffff0010, 0x11111111, 0x13131313; found %s)" % hexes(s))
        gdb.cmd("tbreak loop_2"); gdb.cmd("continue")
        s = [gdb.value("$s%d" % i) for i in (1, 2, 3)]
        check(s == [0xffff0011, 0x22222222, 0x23232323],
              "and process_2 has its s1, s2 and s3 (0xffff0011, 0x22222222, 0x23232323; found %s)" % hexes(s))

        # --- mtime goes on into its high word
        before = mtime()
        gdb.cmd("set {unsigned}0x0200bff8 = 0xffff0000")
        now = mtime()
        check(before < 1 << 32 and 0xffff0000 <= now < 1 << 32,
              "gdb sets mtime just below 2^32 (it was 0x%x and is now 0x%x)" % (before, now))
        for _ in range(TIMEOUT):
            gdb.go(); time.sleep(1); gdb.halt()
            now = mtime()
            if now >= 1 << 32: break
        check(now >= 1 << 32, "mtime goes on into its high word (it is now 0x%x)" % now)
        gdb.cmd("break trap_handler")
        causes, pcs1, pcs2, compare, right, left = [], [], [], [], [], []
        try:
            for i in range(16):
                gdb.cmd("continue", timeout=30)
                causes.append(gdb.value("$mcause")); pcs1.append(frame(1)[0]); pcs2.append(frame(2)[0])
                compare.append(gdb.word("0x02004004"))
                both = gdb.word("0xffff0010", "h")
                right.append(both & 0xff); left.append(both >> 8)
        except pexpect.TIMEOUT:
            gdb.halt()
        check(len(causes) == 16 and all(c == 0x80000007 for c in causes),
              "the timer interrupt keeps coming: 16 more interrupts with mcause 0x80000007 (%d came)" % len(causes))
        check(len(compare) == 16 and all(c == 1 for c in compare), "the high word of mtimecmp is 1 at each of them")
        check(len(set(pcs1)) >= 3 and len(set(pcs2)) >= 3 and all(in_1(pc) for pc in pcs1) and all(in_2(pc) for pc in pcs2),
              "both processes go on running: the saved pc keeps changing in both trap frames (%d and %d different values)"
              % (len(set(pcs1)), len(set(pcs2))))
        check(len(set(right)) >= 3 and len(set(left)) >= 3 and set(right) | set(left) <= DIGITS,
              "and both digits' registers keep changing (right %s; left %s)" % (hexes(sorted(set(right))), hexes(sorted(set(left)))))
        gdb.cmd("delete")
        gdb.cmd("detach")
finally:
    stop(gdb.p if gdb else None, sim)
print("all passed" if not failed else "%d failed" % failed)
sys.exit(1 if failed else 0)
PYEOF
