#!/bin/bash
# Tests the programs of this folder without a window: builds each one, runs it in Logisim's text
# mode and checks what it prints (and, for echo, what it prints back), and runs it with the CPU's
# GDB server on, stops it with gdb at its final loop (halt) and checks the registers and memory
# that hold its result. One PASS or FAIL line per program; the exit status is 1 if any failed.
#
#   ./test.sh [program ...]      (default: all nine)
#
# Environment: LOGISIM_JAR (default: the jar in ../../ref, beside the worktree, if it is there,
# otherwise the one in the top folder of the supplement; the test never downloads one),
# BASE_PORT (default 3380; the n-th program takes the gdb port BASE_PORT+n-1), LOGS (the folder for
# the logs; default: a new temporary folder), RISCV_TOOL_PREFIX (passed to make, if set).
# Nothing opens a window: every step runs with DISPLAY unset.
# By Pavel Gladyshev, licensed under Creative Commons Attribution International license 4.0

dir=$(cd "$(dirname "$0")" && pwd)
top=$(cd "$dir/.." && pwd)
if [ -z "$LOGISIM_JAR" ]; then
  LOGISIM_JAR=$top/../ref/logisim-evolution-ucd-5.0.10-all.jar
  [ -f "$LOGISIM_JAR" ] || LOGISIM_JAR=$top/logisim-evolution-ucd-5.0.10-all.jar
fi
if [ ! -f "$LOGISIM_JAR" ]; then
  echo "test.sh: no Logisim jar at $LOGISIM_JAR (set LOGISIM_JAR, or run make logisim in $dir)"
  exit 1
fi
BASE_PORT=${BASE_PORT:-3380}
LOGS=${LOGS:-$(mktemp -d)}
mkdir -p "$LOGS"
unset DISPLAY

ALL="example1 memory led max looping subroutine sort-word-array echo example"
PROGRAMS=${*:-$ALL}

# What each program must print in text mode (a Python regular expression; empty: nothing to check)
# and what gdb must find when the program reaches halt (printf commands and the expected lines).
declare -A PRINTS=(
  [looping]='^Hello$'
  [subroutine]='^Hello\r*\nGoodbye\r*\n$'
)
declare -A GDB=(
  [example1]='printf "RESULT x23=%d x24=%d\n", $x23, $x24'
  [example]='printf "RESULT s0=%d sum=%d sum-at=0x%x\n", $s0, *(int *)&sum, (int)&sum'
  [memory]='printf "RESULT A=%d B=%d\n", *(int *)&A, *(int *)&B'
  [led]='printf "RESULT right digit=0x%02x left digit=0x%02x\n", *(unsigned char *)0xffff0010, *(unsigned char *)0xffff0011'
  [max]='printf "RESULT t4=%d\n", $t4'
  [looping]='printf "RESULT t1=%d t0-hi=%d\n", $t1, $t0 - (int)&hi'
  [subroutine]='printf "RESULT t1=%d ra-halt=%d\n", $t1, $ra - (int)&halt'
  [sort-word-array]='printf "RESULT A=%d,%d,%d,%d,%d Ainit=%d,%d,%d,%d,%d\n", ((int *)&A)[0], ((int *)&A)[1], ((int *)&A)[2], ((int *)&A)[3], ((int *)&A)[4], ((int *)&Ainit)[0], ((int *)&Ainit)[1], ((int *)&Ainit)[2], ((int *)&Ainit)[3], ((int *)&Ainit)[4]'
)
declare -A EXPECT=(
  [example1]='RESULT x23=32 x24=192'
  [example]='RESULT s0=3 sum=0 sum-at=0x18'
  [memory]='RESULT A=1 B=6'
  [led]='RESULT right digit=0x06 left digit=0x00'
  [max]='RESULT t4=10'
  [looping]='RESULT t1=0 t0-hi=5'
  [subroutine]='RESULT t1=0 ra-halt=0'
  [sort-word-array]='RESULT A=1,2,4,10,20 Ainit=4,20,2,1,10'
)

# session.py MODE PROGRAM PORT: runs make run (MODE run or echo) or make debug with make gdb (MODE
# gdb) in a pty, like a reader's terminal, then stops make with Ctrl-C and checks that make and
# everything it started have gone. Prints what went wrong, if anything; exit status 0 if nothing did.
session() {
python3 -I - "$@" <<'PYEOF'
import os, re, subprocess, sys, time
import pexpect
mode, prog, port, logs, jar, gdbcmds, expect, prints = sys.argv[1:9]
port = int(port)
mk = ["PROG=" + prog, "LOGISIM_JAR=" + jar]
if os.environ.get("RISCV_TOOL_PREFIX"):
    mk.append("RISCV_TOOL_PREFIX=" + os.environ["RISCV_TOOL_PREFIX"])
problems = []
target = ["debug", "GDB_PORT=%d" % port] if mode == "gdb" else ["run"]
child = pexpect.spawn("make", mk + target, encoding="utf-8", timeout=5)
class Tee:
    # keeps everything make and Logisim print, in the log file and in text
    def __init__(self, path): self.f = open(path, "w"); self.text = ""
    def write(self, s): self.f.write(s); self.text += s
    def flush(self): self.f.flush()
    def close(self): self.f.close()
log = Tee(os.path.join(logs, "%s-%s.log" % (prog, mode)))
child.logfile_read = log
def pump(seconds):
    try: child.expect(pexpect.TIMEOUT, timeout=seconds)
    except pexpect.EOF: pass
def started():
    # what the computer printed: everything after the line that starts java (None before it)
    out = log.text
    i = out.find("--tty raw")
    if i < 0: return None
    j = out.find("\n", i)
    return None if j < 0 else out[j + 1:]
def wait_for(cond, seconds):
    end = time.time() + seconds
    while time.time() < end:
        pump(0.5)
        if cond(): return True
    return False

if mode == "gdb":
    listening = lambda: (":%d" % port) in subprocess.run(["ss", "-ltn", "sport = :%d" % port],
                                            capture_output=True, text=True).stdout
    if not wait_for(listening, 60):
        problems.append("the GDB server never listened on port %d" % port)
    else:
        cmdfile = os.path.join(logs, prog + ".gdb")
        with open(cmdfile, "w") as f:
            f.write("break halt\ncontinue\n"
                    'printf "AT pc-halt=%d\\n", $pc - (int)&halt\n' + gdbcmds + "\n")
        wrapper = os.path.join(logs, prog + "-gdb.sh")
        with open(wrapper, "w") as f:
            f.write('#!/bin/sh\nexec gdb-multiarch -batch "$@" -x "%s"\n' % cmdfile)
        os.chmod(wrapper, 0o755)
        try:
            r = subprocess.run(["make", "gdb", "GDB=" + wrapper, "GDB_PORT=%d" % port] + mk,
                               capture_output=True, text=True, timeout=90)
            g = r.stdout + r.stderr
        except subprocess.TimeoutExpired as e:
            g = "gdb did not finish in 90 s"
        with open(os.path.join(logs, prog + "-gdb.out"), "w") as f:
            f.write(g)
        if "Breakpoint 1, " not in g or "AT pc-halt=0" not in g.splitlines():
            problems.append("gdb did not stop at halt")
        got = [l for l in g.splitlines() if l.startswith("RESULT")]
        if got != [expect]:
            problems.append("gdb found %r, expected %r" % (got, expect))
elif mode == "run":
    if not wait_for(lambda: started() is not None, 60):
        problems.append("Logisim did not start")
    # give the program time to print everything (it prints in well under a second)
    pump(5)
    s = started() or ""
    if not re.search(prints, s):
        problems.append("printed %r, expected %r" % (s, prints))
    # a control: what is typed is not shown by the terminal itself (none of these programs reads it)
    child.send("xyz")
    pump(3)
    if "xyz" in (started() or ""):
        problems.append("the terminal echoes what is typed: the echo test would prove nothing")
elif mode == "echo":
    if not wait_for(lambda: started() is not None, 60):
        problems.append("Logisim did not start")
    pump(3)
    typed = "Echo 123"
    for c in typed:
        child.send(c)
        time.sleep(0.1)
    if not wait_for(lambda: typed in (started() or ""), 20):
        problems.append("typed %r, the terminal shows %r" % (typed, started()))
    elif (started() or "") != typed:
        problems.append("typed %r, the terminal shows %r" % (typed, started()))

pgid = child.pid
child.sendintr()
for _ in range(30):
    if not child.isalive(): break
    pump(0.5)
if child.isalive():
    problems.append("make still running after Ctrl-C")
    try: os.killpg(pgid, 9)
    except OSError: pass
left = []
for _ in range(20):
    left = subprocess.run(["ps", "-o", "pid=", "-g", str(pgid)], capture_output=True, text=True).stdout.split()
    if not left: break
    time.sleep(0.5)
if left:
    problems.append("processes left after Ctrl-C: %s" % left)
    for p in left:
        try: os.kill(int(p), 9)
        except OSError: pass
log.close()
for p in problems: print("        " + p)
sys.exit(1 if problems else 0)
PYEOF
}

MAKEVARS=(LOGISIM_JAR="$LOGISIM_JAR")
[ -n "$RISCV_TOOL_PREFIX" ] && MAKEVARS+=(RISCV_TOOL_PREFIX="$RISCV_TOOL_PREFIX")
failed=0
n=0
for p in $PROGRAMS; do
  n=$((n+1)); port=$((BASE_PORT + n - 1))
  report=""
  ok=1
  if [ ! -f "$dir/$p.s" ]; then echo "FAIL  $p: there is no $p.s"; failed=1; continue; fi
  make -C "$dir" PROG="$p" "${MAKEVARS[@]}" > "$LOGS/$p-make.log" 2>&1
  if [ $? -ne 0 ] || [ "$(head -1 "$dir/$p-rom.txt" 2>/dev/null)" != "v2.0 raw" ]; then
    echo "FAIL  $p: make (see $LOGS/$p-make.log)"; failed=1; continue
  fi
  checks="built"
  if [ "$p" = echo ]; then
    (cd "$dir" && session echo "$p" "$port" "$LOGS" "$LOGISIM_JAR" "" "" "") > "$LOGS/$p-problems.txt" || ok=0
    checks="$checks; what is typed comes back"
  fi
  if [ -n "${PRINTS[$p]}" ]; then
    (cd "$dir" && session run "$p" "$port" "$LOGS" "$LOGISIM_JAR" "" "" "${PRINTS[$p]}") >> "$LOGS/$p-problems.txt" || ok=0
    checks="$checks; make run prints /${PRINTS[$p]}/"
  fi
  if [ -n "${GDB[$p]}" ]; then
    (cd "$dir" && session gdb "$p" "$port" "$LOGS" "$LOGISIM_JAR" "${GDB[$p]}" "${EXPECT[$p]}" "") >> "$LOGS/$p-problems.txt" || ok=0
    checks="$checks; at halt gdb finds '${EXPECT[$p]#RESULT }'"
  fi
  make -C "$dir" PROG="$p" clean > /dev/null 2>&1
  if [ $ok = 1 ]; then
    echo "PASS  $p: $checks"
  else
    echo "FAIL  $p: $checks"; sed 's/^/  /' "$LOGS/$p-problems.txt"; failed=1
  fi
done

echo
if [ $failed = 0 ]; then echo "All programs passed. Logs: $LOGS"; else echo "SOME PROGRAMS FAILED. Logs: $LOGS"; fi
exit $failed
