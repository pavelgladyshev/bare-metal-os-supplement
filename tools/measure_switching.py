#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Pavel Gladyshev. Licensed under the MIT licence; see LICENSE-MIT.txt.
"""Where the processor's time goes in a program with two processes and a timer interrupt.

usage: python3 measure_switching.py [options] <ELF file> <record>

  <ELF file>  the program, as its project's make builds it (multitasking, multitasking_racing, ...)
  <record>    what the CPU did at every rising edge of its clock in a run of that program: the file
              that Logisim Evolution UCD writes when it is started with the Java property
              rv32im.trace naming it, for example
                java -Drv32im.trace=run.trace -jar logisim-evolution-ucd-5.0.10-all.jar \\
                     build/multitasking.circ --tty raw
              (stop it with Ctrl-C after a few seconds; the record grows by 16 bytes a clock cycle)

options:
  --skip N      the window starts at the Nth timer interrupt (default 3: both processes have run)
  --switches M  the window holds M switches (default: as many as the record has, an even number)
  --chars C     print the first C characters that the program writes to the terminal (default 0)
  --hz F        the circuit's simulation frequency, ticks a second (default 8192)

The program must have the labels process_1, process_2 and trap_handler, in that order, with main
before them; the handler must end with mret. The script knows two processes only. The program of
Exercise 6 of Chapter 14, which adds a third, is not measured correctly: the third process's
instructions are counted as those of process_2 or of the handler, wherever they lie. To measure
it, Program.part and the tables for each process would have to learn a process_3.

How the record is read. Each 16-byte entry holds what the CPU took at one rising edge (the word on
its Data In, and the interrupt requests) and what it put on the bus after that edge (address, data
out, MemRead, MemWrite, byte enables). The first entry is the bus before the first edge. The CPU
(rv32imData.update) does one step at each edge: when the bus shows an instruction fetch, it takes
the word and executes the instruction, or, if an interrupt is pending and enabled, takes the
interrupt instead and puts the fetch of the handler's first instruction on the bus. A load or a
store puts its own address on the bus after that edge, and finishes at the next edge, so it takes
two clock cycles; every other instruction takes one. This script follows the record edge by edge
in the same way: every edge (clock cycle) is given to the instruction that it executes or
finishes, or to the entry into the handler. It checks as it goes that each fetched word is the
ELF file's word at that address, that an instruction that is not a jump or a branch is followed by
the fetch of the next address, and that a load or a store is followed by a read or a write. An edge
is the entry into the handler when the Timer requests an interrupt at it, the bus shows a fetch
before it and a fetch of trap_handler after it, and the instruction fetched before it cannot go to
trap_handler itself. At the end it compares the counts of interrupts taken, of mret and of the rises
of the Timer's request, and the values of mtime that the handler reads with the record's count of
edges between those reads (mtime counts the same clock).

The terminal's characters are the bytes stored at 0xFFFF000C; the digits' writes are the stores to
0xFFFF0010 and 0xFFFF0011.
"""
import argparse
import collections
import struct
import sys

TTY = 0xFFFF000C
DIGITS = (0xFFFF0010, 0xFFFF0011)
MTIMECMP = 0x02004000
MTIME = 0x0200BFF8
FPGA_TICKS = 2048000          # ticks a second on the FPGA board
TICKS_PER_CYCLE = 2           # a clock cycle is two ticks (high, low)


def read_elf(path):
    """The words of the program's allocated sections, and its symbols: {address: word}, {name: address}."""
    data = open(path, "rb").read()
    if data[:4] != b"\x7fELF" or data[4] != 1 or data[5] != 1:
        sys.exit("measure_switching.py: %s is not a 32-bit little-endian ELF file" % path)
    shoff, = struct.unpack_from("<I", data, 0x20)
    shentsize, shnum, shstrndx = struct.unpack_from("<HHH", data, 0x2E)
    sections = [struct.unpack_from("<IIIIIIIIII", data, shoff + i * shentsize) for i in range(shnum)]
    words, symbols = {}, {}
    for name, kind, flags, addr, off, size, link, info, align, entsize in sections:
        if kind == 1 and flags & 2:                         # PROGBITS, allocated
            for i in range(0, size - size % 4, 4):
                words[addr + i], = struct.unpack_from("<I", data, off + i)
        if kind == 2:                                       # SYMTAB
            strtab = sections[link]
            for i in range(0, size, 16):
                st_name, value, st_size, st_info, other, shndx = struct.unpack_from("<IIIBBH", data, off + i)
                if st_name == 0 or shndx == 0 or shndx >= 0xFF00:
                    continue
                start = strtab[4] + st_name
                text = data[start:data.index(b"\0", start)].decode()
                if not text.startswith(".L") and not text.startswith("$"):
                    symbols[text] = value
    return words, symbols


def read_record(path):
    """The record's entries: (data in, inputs' flags, address, data out, outputs' flags)."""
    raw = open(path, "rb").read()
    n = len(raw) // 16
    return [struct.unpack_from("<IBIIB", raw, 16 * i) for i in range(n)]


def opcode(word):
    return word & 0x7F


def is_transfer(word):
    return opcode(word) in (0x63, 0x6F, 0x67) or word == 0x30200073      # branch, jal, jalr, mret


def next_pcs(pc, word):
    """Where the instruction at pc can go next (mret: anywhere but the handler, in these programs)."""
    op = opcode(word)
    if op == 0x6F:                                                          # jal
        imm = ((word >> 31) & 1) << 20 | ((word >> 12) & 0xFF) << 12 | ((word >> 20) & 1) << 11 | ((word >> 21) & 0x3FF) << 1
        return {(pc + imm - ((imm >> 20) << 21)) & 0xFFFFFFFF}
    if op == 0x63:                                                          # branch
        imm = ((word >> 31) & 1) << 12 | ((word >> 7) & 1) << 11 | ((word >> 25) & 0x3F) << 5 | ((word >> 8) & 0xF) << 1
        return {pc + 4, (pc + imm - ((imm >> 12) << 13)) & 0xFFFFFFFF}
    if op == 0x67 or word == 0x30200073:                                    # jalr, mret
        return set()
    return {pc + 4}


def is_memory(word):
    return opcode(word) in (0x03, 0x23)                                    # load, store


class Program:
    def __init__(self, words, symbols):
        self.words = words
        for name in ("process_1", "process_2", "trap_handler"):
            if name not in symbols:
                sys.exit("measure_switching.py: the program has no label %s" % name)
        self.p1, self.p2, self.handler = symbols["process_1"], symbols["process_2"], symbols["trap_handler"]
        self.text_end = max(a for a in words if a < 0x100000) + 4
        self.labels = sorted((a, n) for n, a in symbols.items() if a < self.text_end and n != "TIME_SLICE")
        self.mret = [a for a, w in words.items() if self.handler <= a and w == 0x30200073]

    def part(self, pc):
        """Which part of the program an instruction belongs to."""
        if pc < self.p1:
            return "main"
        if pc < self.p2:
            return "process_1"
        if pc < self.handler:
            return "process_2"
        return "trap_handler"

    def where(self, pc):
        """label+offset of an address."""
        best = None
        for a, n in self.labels:
            if a <= pc:
                best = (a, n)
        return "%s+%d" % (best[1], pc - best[0]) if pc != best[0] else best[1]


def follow(prog, record):
    """Follows the record edge by edge. Returns the list of steps, one per edge after the first:
    (edge, kind, pc), kind being 'insn' (an instruction executed in one cycle, or the first cycle of a
    load or store), 'data' (the second cycle of a load or store), or 'entry' (the interrupt taken at a
    fetch of pc); and the events (stores, loads from mtime) as (edge, pc, kind, address, value)."""
    steps, events, problems = [], [], []
    address, flags = record[0][2], record[0][4]
    if not flags & 1:
        sys.exit("measure_switching.py: the record does not begin with a fetch")
    state, pc = "fetch", address
    for edge in range(1, len(record)):
        din, fin, address, dout, fout = record[edge]
        if fin & 4:
            problems.append("edge %d: Bus Request" % edge)
        if state == "fetch":
            word = prog.words.get(pc)
            if word is None:
                sys.exit("measure_switching.py: edge %d: fetch at 0x%x, outside the program" % (edge, pc))
            if din != word:
                problems.append("edge %d: fetched 0x%08x at 0x%x, the ELF file has 0x%08x" % (edge, din, pc, word))
            entry = fin & 1 and fout & 1 and address == prog.handler and prog.handler not in next_pcs(pc, word)
            if entry:
                steps.append((edge, "entry", pc))
                pc = address
                continue
            steps.append((edge, "insn", pc))
            if is_memory(word):
                want = 1 if opcode(word) == 0x03 else 2
                if fout & 3 != want:
                    problems.append("edge %d: the %s at 0x%x is not followed by a %s" % (
                        edge, "load" if want == 1 else "store", pc, "read" if want == 1 else "write"))
                events.append((edge, pc, "store" if want == 2 else "load", address, dout, fout))
                state = "data"
                continue
            if fout & 3 != 1:
                problems.append("edge %d: no fetch after the instruction at 0x%x" % (edge, pc))
            if not is_transfer(word) and address != pc + 4:
                problems.append("edge %d: 0x%x is followed by a fetch at 0x%x" % (edge, pc, address))
            pc = address
        else:
            steps.append((edge, "data", pc))
            if events and events[-1][2] == "load" and events[-1][0] == edge - 1:
                e = events[-1]
                events[-1] = (e[0], e[1], "loaded", e[3], din, e[5])        # the word that the load took
            if fout & 3 != 1:
                problems.append("edge %d: no fetch after the load or store at 0x%x" % (edge, pc))
            state, pc = "fetch", address
    return steps, events, problems


def lane_byte(address, value):
    """The byte that a store puts in the lane of its address."""
    return (value >> (8 * (address & 3))) & 0xFF


def pct(part, whole):
    return "%5.1f %%" % (100.0 * part / whole) if whole else "  -  "


def main():
    ap = argparse.ArgumentParser(description="Where the processor's time goes, from a record of the CPU's clock edges.")
    ap.add_argument("elf")
    ap.add_argument("record")
    ap.add_argument("--skip", type=int, default=3)
    ap.add_argument("--switches", type=int, default=0)
    ap.add_argument("--chars", type=int, default=0)
    ap.add_argument("--hz", type=float, default=8192.0)
    args = ap.parse_args()

    words, symbols = read_elf(args.elf)
    prog = Program(words, symbols)
    record = read_record(args.record)
    steps, events, problems = follow(prog, record)
    print("record: %d clock cycles (edges) after the first entry" % (len(record) - 1))
    for p in problems[:10]:
        print("PROBLEM " + p)
    if problems:
        print("PROBLEM %d in all: the record and the program do not agree" % len(problems))
    else:
        print("check: every fetched word is the ELF file's, every instruction is followed by the bus cycle it must be")

    # the terminal
    if args.chars:
        text = "".join(chr(lane_byte(a, v) & 0x7F) for e, pc, k, a, v, f in events if k == "store" and a == TTY)
        print("\nthe first %d characters written to the terminal (of %d):" % (args.chars, len(text)))
        print(text[:args.chars])
        print("(end)")

    # the switches: an entry, then the handler's instructions up to its mret, then the other process
    entries = [i for i, s in enumerate(steps) if s[1] == "entry"]
    mrets = [i for i, s in enumerate(steps) if s[1] == "insn" and s[2] in prog.mret]
    stores_cmp = [e for e in events if e[2] == "store" and e[3] == MTIMECMP]
    rises = sum(1 for i in range(2, len(record)) if record[i][1] & 1 and not record[i - 1][1] & 1)
    print("\ntimer interrupts taken: %d; mret executed: %d; stores to mtimecmp (low word): %d; "
          "rising edges of the timer's request: %d" % (len(entries), len(mrets), len(stores_cmp), rises))
    if len(entries) < args.skip + 3:
        sys.exit("measure_switching.py: too few timer interrupts in the record")
    last = len(entries) - 1 - args.skip
    m = args.switches or (last - last % 2)
    if args.skip + m >= len(entries):
        sys.exit("measure_switching.py: the record has only %d switches after the first %d" % (last, args.skip))
    first_i, end_i = entries[args.skip - 1], entries[args.skip - 1 + m]   # the window: [first_i, end_i)
    window = steps[first_i:end_i]
    first_edge, end_edge = window[0][0], steps[end_i][0]
    print("window: %d switches, from the timer interrupt number %d (clock cycle %d) to number %d (clock cycle %d): "
          "%d clock cycles" % (m, args.skip, first_edge, args.skip + m, end_edge, end_edge - first_edge))

    cycles, insns = collections.Counter(), collections.Counter()
    for edge, kind, pc in window:
        part = "entry" if kind == "entry" else prog.part(pc)
        cycles[part] += 1
        if kind == "insn":
            insns[part] += 1
    tc, ti = sum(cycles.values()), sum(insns.values())
    print("\nshares in the window      clock cycles            instructions")
    for part in ("trap_handler", "entry", "process_1", "process_2", "main"):
        if cycles[part] or part != "main":
            name = part if part != "entry" else "taking the interrupt"
            print("  %-22s %9d %s     %9d %s" % (name, cycles[part], pct(cycles[part], tc),
                                                insns[part], pct(insns[part], ti) if part != "entry" else ""))
    print("  %-22s %9d %s     %9d %s" % ("all", tc, pct(tc, tc), ti, pct(ti, ti)))
    print("  handler and entry      %9d %s" % (cycles["trap_handler"] + cycles["entry"],
                                               pct(cycles["trap_handler"] + cycles["entry"], tc)))

    # one switch and one quantum, for each switch of the window
    sw_cyc, sw_ins, q_cyc, q_ins, q_dig, q_chr, landed = (collections.Counter() for _ in range(7))
    per_quantum_chars = {"process_1": collections.Counter(), "process_2": collections.Counter()}
    landed_by = {"process_1": collections.Counter(), "process_2": collections.Counter()}
    ev_at = {}
    for e in events:
        if e[2] == "store":
            ev_at[e[0] + 1] = e                                   # the store finishes at the next edge
    periods = []
    for k in range(args.skip - 1, args.skip - 1 + m):
        a, b = entries[k], entries[k + 1]
        steps_k = steps[a:b]
        # the handler: from its first instruction to its mret, both included
        mret_i = next(i for i in range(a, b) if steps[i][1] == "insn" and steps[i][2] in prog.mret)
        handler_steps = steps[a + 1:mret_i + 1]
        if any(prog.part(s[2]) != "trap_handler" for s in handler_steps):
            sys.exit("measure_switching.py: something other than the handler runs between an entry and mret")
        sw_cyc[len(handler_steps)] += 1
        sw_ins[sum(1 for s in handler_steps if s[1] == "insn")] += 1
        # the quantum: after mret, up to the next entry
        quantum = steps[mret_i + 1:b]
        who = prog.part(steps[b][2])
        q_cyc[(who, len(quantum))] += 1
        q_ins[(who, sum(1 for s in quantum if s[1] == "insn"))] += 1
        dig = chars = 0
        for s in quantum:
            e = ev_at.get(s[0])
            if e and s[1] == "data":
                if e[3] in DIGITS:
                    dig += 1
                if e[3] == TTY:
                    chars += 1
        q_dig[(who, dig)] += 1
        per_quantum_chars[who][chars] += 1
        landed_by[who][prog.where(steps[b][2])] += 1
        periods.append(steps[b][0] - steps[a][0])

    def dist(counter, who=None):
        items = sorted((k[1], v) for k, v in counter.items() if who is None or k[0] == who)
        return ", ".join("%d (x%d)" % kv for kv in items)

    print("\none switch, from the handler's first instruction to its mret, both included:")
    print("  instructions: %s" % ", ".join("%d (x%d)" % kv for kv in sorted(sw_ins.items())))
    print("  clock cycles: %s   (and 1 clock cycle before it, in which the CPU takes the interrupt)"
          % ", ".join("%d (x%d)" % kv for kv in sorted(sw_cyc.items())))
    print("\none quantum, after mret up to the next timer interrupt:")
    for who in ("process_1", "process_2"):
        n = sum(v for k, v in q_cyc.items() if k[0] == who)
        mean_c = sum(k[1] * v for k, v in q_cyc.items() if k[0] == who) / n
        mean_i = sum(k[1] * v for k, v in q_ins.items() if k[0] == who) / n
        mean_d = sum(k[1] * v for k, v in q_dig.items() if k[0] == who) / n
        print("  %s, %d quanta: clock cycles %s (mean %.1f)" % (who, n, dist(q_cyc, who), mean_c))
        print("    instructions %s (mean %.1f)" % (dist(q_ins, who), mean_i))
        print("    writes to a digit %s (mean %.2f)" % (dist(q_dig, who), mean_d))
        pc_ = per_quantum_chars[who]
        print("    characters to the terminal %s (mean %.2f)" % (
            ", ".join("%d (x%d)" % kv for kv in sorted(pc_.items())), sum(k * v for k, v in pc_.items()) / n))
        print("    the interrupt landed at: %s" % ", ".join(
            "%s (x%d)" % kv for kv in sorted(landed_by[who].items(), key=lambda kv: (-kv[1], kv[0]))))
    pm = sum(periods) / len(periods)
    print("\nfrom one timer interrupt to the next: %s clock cycles (mean %.1f)" % (
        ", ".join("%d (x%d)" % kv for kv in sorted(collections.Counter(periods).items())), pm))
    print("  = %.4f s at the circuit's %g ticks a second (Logisim's window), %.1f us on the FPGA board "
          "(%d ticks a second, %d ticks a clock cycle)" % (pm * TICKS_PER_CYCLE / args.hz, args.hz,
                                                           1e6 * pm * TICKS_PER_CYCLE / FPGA_TICKS, FPGA_TICKS,
                                                           TICKS_PER_CYCLE))

    # mtime as the handler read it, against the record's count of clock cycles
    reads = [(e[0], e[4]) for e in events if e[2] == "loaded" and e[3] == MTIME and prog.part(e[1]) == "trap_handler"]
    if len(reads) > 2:
        diffs = collections.Counter((r2[1] - r1[1]) - (r2[0] - r1[0]) for r1, r2 in zip(reads, reads[1:]))
        print("check: mtime read by the handler minus the record's edges between two reads: %s"
              % ", ".join("%d (x%d)" % kv for kv in sorted(diffs.items())))


if __name__ == "__main__":
    main()
