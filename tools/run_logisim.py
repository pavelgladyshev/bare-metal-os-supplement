#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Pavel Gladyshev. Licensed under the MIT licence; see LICENSE-MIT.txt.
"""Boot a logOS tree in Logisim Evolution UCD without its window and run shell commands in it.

usage: python3 run_logisim.py [--jar JAR] [--timeout SECONDS] <tree> <scratch folder> <command file>

  <tree>            a logOS folder in which "make all" has been run
  <scratch folder>  where the run takes place; it is created if it does not exist
  <command file>    one logOS shell command per line; empty lines and lines that start
                    with # are skipped

example:
  printf 'hello\\nls /bin\\n' > cmds.txt
  python3 run_logisim.py ~/logos-blackrock /tmp/run1 cmds.txt

The script copies computer.circ, boot-rom.txt and block_storage.bin from <tree> into the scratch
folder, so the tree's disk image is not modified. It starts Logisim there, waits for the shell's
"$ " prompt, types each command (30 ms per character: faster typing drops keys) and prints what
came back, with the time each command took. Everything Logisim printed is also kept in
session.log in the scratch folder; look there for the last line of a program's output if it does
not end in a newline, because the script takes that line for the prompt's. The exit status is 2
if a command does not come back to the prompt in time, or if Logisim stops.

The Logisim jar is, in this order: the --jar option; the environment variable LOGISIM_JAR; the
file that "make -s print-LOGISIM_JAR" names in <tree> (logOS's setup.sh downloads it there);
logisim-evolution-ucd-5.0.9-all.jar in <tree>.

Needs Python 3, Java 21 or later, and the pexpect library (pip install pexpect, or
sudo apt install python3-pexpect). It runs on Linux, macOS and Ubuntu on WSL.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import time

import pexpect

DEFAULT_JAR = "logisim-evolution-ucd-5.0.9-all.jar"


def find_jar(tree, option):
    """Return the path of the Logisim jar (see the comment at the top of the file)."""
    jar = option or os.environ.get("LOGISIM_JAR")
    if jar:
        return os.path.abspath(os.path.expanduser(jar))
    try:
        named = subprocess.run(["make", "-s", "print-LOGISIM_JAR"], cwd=tree, text=True,
                               capture_output=True, timeout=60)
        name = named.stdout.strip() if named.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired):
        name = ""
    if len(name.splitlines()) != 1:
        name = DEFAULT_JAR
    return os.path.abspath(os.path.join(tree, os.path.expanduser(name)))


parser = argparse.ArgumentParser(
    description="Boot a logOS tree in Logisim Evolution UCD and run shell commands in it.")
parser.add_argument("--jar", help="the Logisim Evolution UCD jar (default: the one the tree names)")
parser.add_argument("--timeout", type=int, default=900,
                    help="seconds to wait for the prompt after each command (default: 900)")
parser.add_argument("tree", help="a logOS folder in which 'make all' has been run")
parser.add_argument("rundir", metavar="scratch-folder", help="where the run takes place")
parser.add_argument("cmdfile", metavar="command-file", help="one shell command per line")
args = parser.parse_args()

jar = find_jar(args.tree, args.jar)
if not os.path.isfile(jar):
    sys.exit(f"run_logisim.py: no Logisim jar at {jar}\n"
             "(run ./setup.sh in the logOS tree, or give --jar, or set LOGISIM_JAR)")

os.makedirs(args.rundir, exist_ok=True)
for f in ("computer.circ", "boot-rom.txt", "block_storage.bin"):
    shutil.copy(os.path.join(args.tree, f), args.rundir)
with open(args.cmdfile) as cf:
    cmds = [l.rstrip("\n") for l in cf if l.strip() and not l.startswith("#")]
log = open(os.path.join(args.rundir, "session.log"), "w")
t0 = time.time()
p = pexpect.spawn("java", ["-Djava.awt.headless=true", "-jar", jar, "computer.circ", "--tty", "raw"],
                  cwd=args.rundir, encoding="utf-8", codec_errors="replace", timeout=args.timeout)
p.logfile_read = log
PROMPT = re.compile(r"\$ $")


def wait_prompt(what):
    i = p.expect([PROMPT, pexpect.TIMEOUT, pexpect.EOF])
    if i:
        print(f"!! {'TIMEOUT' if i == 1 else 'EOF'} after {what}", flush=True)
        p.terminate(force=True)
        sys.exit(2)


wait_prompt("boot")
print(f"booted in {time.time() - t0:.0f}s", flush=True)
for c in cmds:
    t = time.time()
    for ch in c + "\r":
        p.send(ch)
        time.sleep(0.03)
    wait_prompt(c)
    out = p.before.replace("\r", "")
    out = out.split("\n", 1)[1] if "\n" in out else ""      # drop the echoed command line
    out = "\n".join(out.split("\n")[:-1])                     # drop the cwd before the prompt
    print(f"$ {c}   [{time.time() - t:.0f}s]\n{out}", flush=True)
p.terminate(force=True)
print(f"total {time.time() - t0:.0f}s")
