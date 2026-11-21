#!/bin/bash
# Test of polled_kbd.s in Logisim's text mode, by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
#   ./test.sh
#
# Runs the program with make run, types characters into the computer's keyboard and checks that
# the program sends each of them to the terminal. It prints one PASS or FAIL line per check, and
# its exit status is 1 if any check failed. No window is opened.
#
# Environment: LOGISIM_JAR (default: the jar in the supplement's top folder, where make logisim
# puts it). It needs Python 3 with the pexpect library.

HERE=$(cd "$(dirname "$0")" && pwd)
LOGISIM_JAR=${LOGISIM_JAR:-$HERE/../logisim-evolution-ucd-5.0.10-all.jar}
if [ ! -f "$LOGISIM_JAR" ]; then
    echo "test.sh: no Logisim jar at $LOGISIM_JAR (make logisim fetches it, or set LOGISIM_JAR)"
    exit 2
fi
LOGISIM_JAR=$(realpath "$LOGISIM_JAR")

python3 -I - "$HERE" "$LOGISIM_JAR" <<'PYEOF'
import os, sys, time
import pexpect

HERE, JAR = sys.argv[1:3]
ENV = dict(os.environ); ENV.pop("DISPLAY", None)        # nothing here may open a window
TIMEOUT = 60                                            # seconds for any one wait
failed = 0

def check(ok, text):
    global failed
    print(("PASS  " if ok else "FAIL  ") + text, flush=True)
    failed += not ok

def stop(child):
    """Ctrl-C, as a reader would; then whatever is left of make and the simulator, by process group."""
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

sim = pexpect.spawn("make", ["run", "LOGISIM_JAR=" + JAR], cwd=HERE, env=ENV, encoding="utf-8",
                    codec_errors="replace", timeout=TIMEOUT)
sim.setecho(False)          # the pseudo-terminal must not echo: what comes back is the program's doing
try:
    try:
        started(sim)
        up = True
    except (pexpect.TIMEOUT, pexpect.EOF):
        up = False
    check(up, "make run builds the program and starts the simulator")

    def read(seconds):
        """What the program prints in that time."""
        text = ""
        end = time.time() + seconds
        while time.time() < end:
            try: text += sim.read_nonblocking(1000, timeout=0.25)
            except pexpect.TIMEOUT: pass
            except pexpect.EOF: break
        return text

    def echo(text):
        """Types the text and returns what comes back: it waits for as many characters, then a little more."""
        sim.send(text)
        back = ""
        end = time.time() + TIMEOUT
        while len(back) < len(text) and time.time() < end:
            back += read(0.25)
        return back + read(0.5)

    if up:
        # The simulator takes a few seconds to start. Type a full stop every second until one comes back.
        back = ""
        for _ in range(TIMEOUT):
            sim.send(".")
            back = read(1)
            if back: break
        back += read(2)
        check(back != "" and set(back) == {"."}, "the program echoes a character once the simulator has started")

        one_by_one = "Polling 123"
        back = [echo(ch) for ch in one_by_one]
        check(back == list(one_by_one), "%d characters typed one at a time: each comes back, once, before the next is typed (got %r)"
              % (len(one_by_one), "".join(back)))
        burst = "The quick brown fox jumps."
        back = echo(burst)
        check(back == burst, "%d characters typed at once come back in order, once (got %r)" % (len(burst), back))
        back = read(2)
        check(back == "", "the program prints nothing while nothing is typed (2 seconds; got %r)" % back)
finally:
    stop(sim)
print("all passed" if not failed else "%d failed" % failed)
sys.exit(1 if failed else 0)
PYEOF
