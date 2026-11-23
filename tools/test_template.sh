#!/bin/bash
# Tests the projects' Makefile targets (build, list, run, debug with gdb, gui) with the reference circuit
# and Logisim jar, and prints one PASS or FAIL line per step; the exit status is 1 if any step failed.
#
#   tools/test_template.sh [project ...]       (default: template simple-asm simple-c c-and-assembly pong/blocking
#                                                pong/fsm pong/coroutines pong_interrupt)
#
# Environment: CIRCUIT (for the projects that do not have their own) and LOGISIM_JAR (default: the files in ../ref, beside the worktree),
# SCRATCH (screenshots and logs; default: ../scratch-template), BASE_PORT (default 3370; each project
# takes the next port), RISCV_TOOL_PREFIX (passed to make, if set).
# Nothing opens a window on your screen: only make gui runs with a display, and that is a virtual
# one (xvfb-run); every other step runs with DISPLAY unset.
# make gui also runs with Logisim preferences of its own (in SCRATCH/prefs), not yours.
# By Pavel Gladyshev, licensed under Creative Commons Attribution International license 4.0

top=$(cd "$(dirname "$0")/.." && pwd)
CIRCUIT=${CIRCUIT:-$top/../ref/computer-glendalough.circ}
LOGISIM_JAR=${LOGISIM_JAR:-$top/../ref/logisim-evolution-ucd-5.0.10-all.jar}
SCRATCH=${SCRATCH:-$top/../scratch-template}
BASE_PORT=${BASE_PORT:-3370}
mkdir -p "$SCRATCH"
TMP=$(mktemp -d "$SCRATCH/test.XXXXXX")

# project | executable | ROM image | text that make run prints | gdb breakpoint | text in make list
declare -A INFO=(
  [template]="template|template-rom.txt|Hi|halt|j *halt"
  [simple-asm]="simple-asm|simple-asm-rom.txt|Hi|halt|j *halt"
  [simple-c]="simple-c|simple-c-rom.txt|Hello world!|main|CONSOLE_DATA = c"
  [c-and-assembly]="c-and-assembly|c-and-assembly-rom.txt|Hello from C, printed by assembly!|print|jr ra"
  [pong/blocking]="pong-blocking|pong-blocking.bin.txt|input new coords as X,Y<Enter>|main|<main>:"
  [pong/fsm]="pong-fsm|pong-fsm.bin.txt|input new coords as X,Y<Enter>|main|<main>:"
  [pong/coroutines]="pong-coroutines|pong-coroutines.bin.txt|input new coords as X,Y<Enter>|main|<main>:"
  [pong_interrupt]="pong_interrupt|pong_interrupt.bin.txt|input new coords as X,Y<Enter>|main|<main>:"
)
ALL="template simple-asm simple-c c-and-assembly pong/blocking pong/fsm pong/coroutines pong_interrupt"
PROJECTS=${*:-$ALL}

failed=0
pass() { echo "PASS  $1: $2"; }
fail() { echo "FAIL  $1: $2"; failed=1; }
# check PROJECT STEP COMMAND...: PASS if the command succeeds
check() { local p=$1 s=$2; shift 2; if "$@"; then pass "$p" "$s"; else fail "$p" "$s"; fi; }

# A make target in a pty, like a reader's terminal: waits for TEXT in its output (and, with --port,
# for a TCP port to be listened on), runs COMMAND (--after), sends Ctrl-C and checks that make and
# everything it started has gone. Prints the output to FILE.
session() {
python3 -I - "$@" <<'PYEOF'
import argparse, os, subprocess, sys, time
import pexpect
ap = argparse.ArgumentParser()
ap.add_argument("--out"); ap.add_argument("--expect", default=""); ap.add_argument("--port", type=int, default=0)
ap.add_argument("--after", default=""); ap.add_argument("--dir"); ap.add_argument("cmd", nargs=argparse.REMAINDER)
a = ap.parse_args()
env = dict(os.environ); env.pop("DISPLAY", None)
child = pexpect.spawn(a.cmd[0], a.cmd[1:], cwd=a.dir, env=env, encoding="utf-8", timeout=5)
log = open(a.out, "w"); child.logfile_read = log
def pump(seconds):
    try: child.expect(pexpect.TIMEOUT, timeout=seconds)
    except pexpect.EOF: pass
ok = True
if a.port:
    for _ in range(60):
        pump(0.5)
        r = subprocess.run(["ss", "-ltn", "sport = :%d" % a.port], capture_output=True, text=True).stdout
        if ":%d" % a.port in r: break
    else:
        print("port %d never listened on" % a.port, file=sys.stderr); ok = False
if ok and a.after:
    r = subprocess.run(a.after, shell=True, cwd=a.dir, env=env, timeout=60)
    ok = r.returncode == 0
    if not ok: print("--after command failed: %d" % r.returncode, file=sys.stderr)
if ok and a.expect:
    try: child.expect_exact(a.expect, timeout=30)
    except (pexpect.TIMEOUT, pexpect.EOF):
        print("did not print %r" % a.expect, file=sys.stderr); ok = False
pump(1)
pgid = child.pid
child.sendintr()
for _ in range(30):
    if not child.isalive(): break
    pump(0.5)
if child.isalive():
    print("still running after Ctrl-C", file=sys.stderr); ok = False
    try: os.killpg(pgid, 9)
    except OSError: pass
time.sleep(0.5)
left = subprocess.run(["ps", "-o", "pid=", "-g", str(pgid)], capture_output=True, text=True).stdout.split()
if left:
    print("processes left after Ctrl-C: %s" % left, file=sys.stderr); ok = False
    for p in left:
        try: os.kill(int(p), 9)
        except OSError: pass
log.close()
sys.exit(0 if ok else 1)
PYEOF
}

gui_step() {   # gui_step PROJECT DIR TARGET SCREENSHOT
python3 -I - "$@" <<'PYEOF'
import os, subprocess, sys, time, shutil
project, d, target, shot = sys.argv[1:5]
inner = r'''
cd "$1"; shift
"$@" &
m=$!
found=""
for i in $(seq 1 120); do
  for p in $m $(pgrep -P $m); do
    w=$(xdotool search --pid $p 2>/dev/null | head -1)
    [ -n "$w" ] && found=$p && break 2
  done
  sleep 0.5
done
if [ -n "$found" ]; then sleep 10; import -window root "$SHOT"; echo window $w of $found; fi
for p in $(pgrep -P $m); do kill $p; done
kill $m
sleep 1
for p in $(pgrep -P $m); do kill -9 $p; done
[ -n "$found" ]
'''
# Logisim writes its preferences (recent files, window size) even on a virtual display: give it
# preferences of its own, so that the test never touches yours
prefs = os.path.join(os.path.dirname(shot), "prefs")
env = dict(os.environ, SHOT=shot, JAVA_TOOL_OPTIONS="-Djava.util.prefs.userRoot=" + prefs)
cmd = ["xvfb-run", "-a", "-s", "-screen 0 1700x1100x24", "bash", "-c", inner, "bash", d] + sys.argv[5:]
r = subprocess.run(cmd, env=env, timeout=180)
sys.exit(r.returncode)
PYEOF
}

n=0
for p in $PROJECTS; do
  n=$((n+1)); port=$((BASE_PORT + n - 1))
  IFS='|' read -r exe rom runtext brk listtext <<< "${INFO[$p]}"
  if [ -z "$exe" ]; then fail "$p" "unknown project"; continue; fi
  dir=$top/$p
  safe=${p//\//-}
  # a project that names its own circuit (the pong projects) keeps it; the others get CIRCUIT
  MAKEVARS=(LOGISIM_JAR="$LOGISIM_JAR")
  grep -q '^CIRCUIT *=' "$dir/Makefile" || MAKEVARS+=(CIRCUIT="$CIRCUIT")
  [ -n "$RISCV_TOOL_PREFIX" ] && MAKEVARS+=(RISCV_TOOL_PREFIX="$RISCV_TOOL_PREFIX")
  mk() { make -C "$dir" "$@" "${MAKEVARS[@]}"; }
  echo "--- $p (gdb port $port)"

  # make clean
  mk clean > "$TMP/$safe-clean.log" 2>&1
  check "$p" "make clean (no ELF file, no ROM image, no circuit copy left)" test ! -e "$dir/$exe" -a ! -e "$dir/$rom" -a -z "$(ls "$dir"/build/*.circ 2>/dev/null)"

  # make
  mk > "$TMP/$safe-make.log" 2>&1
  check "$p" "make (ELF file, listing, ROM image 'v2.0 raw')" \
      bash -c "test -s '$dir/$exe' && test -s '$dir/$exe.asm' && test \"\$(head -1 '$dir/$rom')\" = 'v2.0 raw' && test \$(wc -l < '$dir/$rom') -gt 5"

  # make list
  mk list > "$TMP/$safe-list.out" 2>"$TMP/$safe-list.err"
  check "$p" "make list (addresses, instructions and source)" \
      bash -c "grep -qE '^ +[0-9a-f]+:[[:space:]]+[0-9a-f]{8}[[:space:]]' '$TMP/$safe-list.out' && grep -q '$listtext' '$TMP/$safe-list.out'"

  # make run, stopped with Ctrl-C
  session --dir "$dir" --out "$TMP/$safe-run.out" --expect "$runtext" make run "${MAKEVARS[@]}" 2> "$TMP/$safe-run.err"
  check "$p" "make run prints '$runtext', Ctrl-C stops it" test $? -eq 0
  [ -s "$TMP/$safe-run.err" ] && sed 's/^/        /' "$TMP/$safe-run.err"

  # make debug with a scripted gdb
  cat > "$TMP/$safe-gdb.cmds" <<GDBEOF
break $brk
continue
info registers pc
stepi
info registers pc
x/4i \$pc
GDBEOF
  cat > "$TMP/$safe-gdb.sh" <<GDBEOF
#!/bin/sh
exec gdb-multiarch -batch "\$@" -x "$TMP/$safe-gdb.cmds"
GDBEOF
  chmod +x "$TMP/$safe-gdb.sh"
  session --dir "$dir" --out "$TMP/$safe-debug.out" --port "$port" --expect "$runtext" \
      --after "make gdb GDB='$TMP/$safe-gdb.sh' GDB_PORT=$port > '$TMP/$safe-gdb.out' 2>&1" \
      make debug GDB_PORT=$port "${MAKEVARS[@]}" 2> "$TMP/$safe-debug.err"
  check "$p" "make debug and make gdb ran; the program printed '$runtext'; Ctrl-C stops make debug" test $? -eq 0
  [ -s "$TMP/$safe-debug.err" ] && sed 's/^/        /' "$TMP/$safe-debug.err"
  check "$p" "gdb stopped at '$brk' (Breakpoint 1)" grep -q "Breakpoint 1, " "$TMP/$safe-gdb.out"
  check "$p" "gdb: info registers pc, stepi, x/4i \$pc" \
      bash -c "test \$(grep -c '^pc  *0x' '$TMP/$safe-gdb.out') -eq 2 && grep -q '^=> 0x' '$TMP/$safe-gdb.out'"

  # make gui in a virtual display
  shot=$SCRATCH/gui-$safe.png
  rm -f "$shot"
  gui_step "$p" "$dir" gui "$shot" make gui "${MAKEVARS[@]}" > "$TMP/$safe-gui.out" 2>&1
  check "$p" "make gui: a window appears (screenshot $shot)" bash -c "test -s '$shot'"
  mk clean > /dev/null 2>&1
done

echo
if [ $failed = 0 ]; then echo "All steps passed. Logs: $TMP"; else echo "SOME STEPS FAILED. Logs: $TMP"; fi
exit $failed
