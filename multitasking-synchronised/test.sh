#!/bin/bash
# Test of multitasking_racing_synchronised.s in Logisim's text mode, by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
#   ./test.sh
#
# Runs the program with make run, takes the first 400 lines that it prints and checks that every
# one of them is a whole message, and that both processes print. What the program printed is
# kept in build/test-output.txt. It prints one PASS or FAIL line per check, and its exit status
# is 1 if any check failed. No window is opened.
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
MSG1 = "My funny bone has a fracture.\n"
MSG2 = "It's not rocket surgery.\n"
failed = 0

def check(ok, text):
    global failed
    print(("PASS  " if ok else "FAIL  ") + text, flush=True)
    failed += not ok

def stop(child):
    """Ctrl-C, as a reader would; then whatever is left of make and the simulator, by process group."""
    if child is None: return
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

def run(lines):
    """make run; returns what the program printed, up to its first so many line ends (or nothing in TIMEOUT seconds)."""
    sim = None
    text = ""
    try:
        sim = pexpect.spawn("make", ["run", "LOGISIM_JAR=" + JAR], cwd=HERE, env=ENV, encoding="utf-8",
                            codec_errors="replace", timeout=TIMEOUT)
        started(sim)
        end = time.time() + TIMEOUT
        while text.count("\n") < lines and time.time() < end:
            try: text += sim.read_nonblocking(4000, timeout=1).replace("\r", "")
            except pexpect.TIMEOUT: pass
            except pexpect.EOF: break
    except (pexpect.TIMEOUT, pexpect.EOF):
        pass
    finally:
        stop(sim)
    return text

def interleaved(text):
    """True if the text is the characters of the two endless streams of messages, each in its
    order, shuffled together: nothing lost, nothing added. It follows every way of splitting
    the text between the streams: a set of pairs (place in message 1, place in message 2)."""
    places = {(0, 0)}
    for c in text:
        places = ({((i + 1) % len(MSG1), j) for i, j in places if MSG1[i] == c} |
                  {(i, (j + 1) % len(MSG2)) for i, j in places if MSG2[j] == c})
        if not places: return False
    return True

LINES = 400
text = run(LINES)
try:
    with open(os.path.join(HERE, "build", "test-output.txt"), "w") as f: f.write(text)
except OSError:
    pass
lines = text.split("\n")[:-1]                           # without the unfinished last line
first = sum(line + "\n" == MSG1 for line in lines)
second = sum(line + "\n" == MSG2 for line in lines)
check(len(lines) >= LINES, "make run: the program prints %d lines (%d characters)" % (len(lines), len(text)))
check(lines != [] and first + second == len(lines),
      "every line is one whole message: %d of %d lines" % (first + second, len(lines)))
check(first >= LINES // 10 and second >= LINES // 10,
      "both processes print: %d times the first message and %d times the second" % (first, second))
last = text.split("\n")[-1]
check(MSG1.startswith(last) or MSG2.startswith(last), "the unfinished last line is the beginning of a message (%r)" % last)
turns = sum(a != b for a, b in zip(lines, lines[1:]))
print("      the messages change places %d times in %d lines" % (turns, len(lines)))
print("all passed" if not failed else "%d failed" % failed)
sys.exit(1 if failed else 0)
PYEOF
