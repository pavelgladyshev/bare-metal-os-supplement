#!/usr/bin/env python3
# Tests of the simulated computer (../computer.circ) by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
"""Runs the quick tests of computer.circ in Logisim's text mode and says which passed.

usage: python3 run_tests.py --jar JAR [--circuit ../computer.circ] [--gdb gdb-multiarch]
                            [--port 3333] [test ...]

  digits   digits.S: the two seven-segment digits, written and read with every width
  kbdirq   kbdirq.S: the keyboard interrupt, with the characters typed by this script
  timer    timer.S: the Timer's registers after reset, and the timer interrupt
  gdb      kbdirq.S again with the CPU's GDB server on: gdb stops in the interrupt handler and
           prints mip, mie, mcause and mstatus, and reads the device registers
  empty    the circuit as it is, with nothing in its ROM: where gdb finds the CPU after 100 steps

Each test runs a copy of the circuit in build/ (so that the simulator's block_storage.bin is made
there) and compares what came out with the file <test>.expected beside this script; what came out
is kept in build/<test>.out. "make" must have built the programs first (make test does both).
The exit status is 0 when every test passed.
"""
import argparse
import os
import re
import shutil
import sys

import pexpect

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
TIMEOUT = 120      # seconds for any one wait

parser = argparse.ArgumentParser(description="Run the quick tests of computer.circ.")
parser.add_argument("--jar", required=True, help="the Logisim Evolution UCD jar (5.0.10 or later)")
parser.add_argument("--circuit", default=os.path.join(HERE, "..", "computer.circ"))
parser.add_argument("--gdb", default="gdb-multiarch", help="a gdb that knows RISC-V")
parser.add_argument("--port", type=int, default=3333, help="TCP port for the CPU's GDB server")
parser.add_argument("tests", nargs="*", default=["digits", "kbdirq", "timer", "gdb", "empty"])
args = parser.parse_args()
if not os.path.isfile(args.jar):
    sys.exit(f"run_tests.py: no Logisim jar at {args.jar} (make logisim in a project folder "
             "fetches it; or give LOGISIM_JAR=... to make)")
JAR = os.path.abspath(args.jar)


def circuit_copy(name, debug=False):
    """A copy of the circuit in build/; with debug, the CPU's GDB server is on and the CPU waits."""
    with open(args.circuit) as f:
        text = f.read()
    if debug:
        tag = 'name="RV32IM CPU">'
        assert text.count(tag) == 1, "the circuit's RV32IM CPU was not found"
        text = text.replace(tag, tag + f'<a name="gdbServerRunning" val="true"/><a name="tcpPort" val="{args.port}"/>')
    path = os.path.join(BUILD, name)
    with open(path, "w") as f:
        f.write(text)
    return path


def simulator(circuit, image=None):
    """Logisim in text mode: the terminal is the computer's TTY and keyboard."""
    cmd = ["-Djava.awt.headless=true", "-jar", JAR, circuit, "--tty", "raw"]
    if image:
        cmd += ["--load", os.path.join(BUILD, image), "ROM_1"]
    return pexpect.spawn("java", cmd, cwd=BUILD, encoding="utf-8", codec_errors="replace", timeout=TIMEOUT)


def stop(*processes):
    for p in processes:
        if p is not None and p.isalive():
            p.terminate(force=True)


def test_digits():
    sim = simulator(circuit_copy("digits.circ"), "digits.txt")
    try:
        sim.expect_exact("done\r\n")
        return sim.before + "done\n"
    finally:
        stop(sim)


def test_timer():
    sim = simulator(circuit_copy("timer.circ"), "timer.txt")
    try:
        sim.expect_exact("done\r\n")
        return sim.before + "done\n"
    finally:
        stop(sim)


def test_kbdirq():
    """Types a, then b, c, d and a full stop, then z, each when the program is ready for it."""
    sim = simulator(circuit_copy("kbdirq.circ"), "kbdirq.txt")
    out = ""
    try:
        sim.expect_exact("interrupts on in the CPU\r\n  RCR = 00000000\r\n")   # part 1: it waits for a character
        out += sim.before + sim.after
        sim.send("a")
        sim.expect_exact("typed: a")                      # part 2: the handler has echoed it
        out += sim.before + sim.after
        for ch in "bcd.":
            sim.send(ch)
            sim.expect_exact(ch)
            out += sim.before + sim.after
        sim.expect_exact("part 3: interrupt enable 0\r\n")
        out += sim.before + sim.after
        sim.send("z")
        sim.expect_exact("done\r\n")
        return out + sim.before + sim.after
    finally:
        stop(sim)


def gdb_session(elf):
    gdb = pexpect.spawn(args.gdb, ["-q", "-nx"] + ([elf] if elf else []), cwd=BUILD, encoding="utf-8",
                        codec_errors="replace", timeout=TIMEOUT, env=dict(os.environ, TERM="dumb"))
    gdb.expect_exact("(gdb) ")

    def command(line, wait=True):
        gdb.sendline(line)
        if not wait:
            return ""
        gdb.expect_exact("(gdb) ")
        answer = gdb.before.replace("\r", "")
        return answer.split("\n", 1)[1] if "\n" in answer else ""     # without the echoed command

    for line in ("set pagination off", "set confirm off", "set style enabled off", "set width 0",
                 "set architecture riscv:rv32", "set osabi none", f"target remote localhost:{args.port}"):
        command(line)
    return gdb, command


def value(command, expression):
    """What gdb prints for p/x expression, without its "$n = "."""
    m = re.search(r"= (\S+)", command("p/x " + expression))
    return m.group(1) if m else "?"


def test_gdb():
    sim = simulator(circuit_copy("kbdirq-debug.circ", debug=True), "kbdirq.txt")
    gdb = None
    out = []
    try:
        sim.expect("(?i)gdb|waiting|listening", timeout=30)   # the server says that it is waiting
    except pexpect.TIMEOUT:
        pass
    try:
        gdb, command = gdb_session("kbdirq")
        out.append("at reset:")
        for reg in ("pc", "priv", "mstatus", "mip", "mie", "mcause"):
            out.append(f"  {reg} = {value(command, '$' + reg)}")
        command("break handler")
        command("continue", wait=False)
        sim.expect_exact("interrupts on in the CPU\r\n  RCR = 00000000\r\n")   # it waits for a character
        sim.send("a")
        gdb.expect_exact("(gdb) ")                        # the breakpoint in the handler
        out.append("in the interrupt handler, before it reads the character:")
        for reg in ("mip", "mie", "mcause", "mstatus"):
            out.append(f"  {reg} = {value(command, '$' + reg)}")
        out.append(f"  priv = {value(command, '$priv')}")
        out.append("  the pc is the handler's address: " + value(command, "$pc == (unsigned)&handler"))
        out.append("  mepc is in main: " + value(command, "$mepc >= (unsigned)&main && $mepc < (unsigned)&handler"))
        out.append("  x/xw 0xffff0004 (RCR)        " + command("x/xw 0xffff0004").strip().split("\t")[-1])
        command("tbreak after_read")                      # after the handler's read of the character
        command("continue")
        command("stepi")                                  # the CPU takes mip from its inputs at each step
        out.append("after the handler has read the character, and one more instruction:")
        out.append(f"  mip = {value(command, '$mip')}")
        out.append("  x/xw 0xffff0004 (RCR)        " + command("x/xw 0xffff0004").strip().split("\t")[-1])
        out.append("  a0 (the character)           " + value(command, "$a0"))
        command("delete")
        command("detach")
        return "\n".join(out) + "\n"
    finally:
        stop(gdb, sim)


def test_empty():
    sim = simulator(circuit_copy("empty-debug.circ", debug=True))
    gdb = None
    out = []
    try:
        sim.expect("(?i)gdb|waiting|listening", timeout=30)
    except pexpect.TIMEOUT:
        pass
    try:
        gdb, command = gdb_session(None)
        out.append("the first words of the ROM: " + " ".join(command("x/4xw 0").strip().split("\t")[1:]))
        out.append("at reset:        pc = %s  mcause = %s" % (value(command, "$pc"), value(command, "$mcause")))
        command("stepi")
        out.append("after 1 step:    pc = %s  mcause = %s  mepc = %s  mtval = %s  mtvec = %s" % tuple(
            value(command, "$" + r) for r in ("pc", "mcause", "mepc", "mtval", "mtvec")))
        command("stepi 99")
        out.append("after 100 steps: pc = %s  mcause = %s  mepc = %s" % tuple(
            value(command, "$" + r) for r in ("pc", "mcause", "mepc")))
        out.append("the digits and the keyboard's register: "
                   + command("x/xw 0xffff0010").strip().split("\t")[-1] + " "
                   + command("x/xw 0xffff0004").strip().split("\t")[-1])
        command("detach")
        return "\n".join(out) + "\n"
    finally:
        stop(gdb, sim)


os.makedirs(BUILD, exist_ok=True)
failed = 0
for name in args.tests:
    try:
        got = globals()["test_" + name]().replace("\r", "")
    except pexpect.ExceptionPexpect as e:
        got = f"!! {type(e).__name__}: the test did not finish\n"
    with open(os.path.join(BUILD, name + ".out"), "w") as f:
        f.write(got)
    expected_file = os.path.join(HERE, name + ".expected")
    expected = open(expected_file).read() if os.path.isfile(expected_file) else None
    if got == expected:
        print(f"PASS  {name}")
    else:
        failed += 1
        print(f"FAIL  {name}: build/{name}.out differs from {name}.expected"
              if expected is not None else f"FAIL  {name}: there is no {name}.expected")
print("all passed" if not failed else f"{failed} failed")
sys.exit(1 if failed else 0)
