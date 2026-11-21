# Tests of the simulated computer (../computer.circ) by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
#   make test        the quick tests: the digits, the keyboard interrupt, the Timer, the
#                    interrupt's CSRs in gdb, and the empty computer (about two minutes)
#   make logos       logOS Belfield, Blackrock and Glendalough on this circuit, compared with the
#                    sessions on their own circuits (logos.sh says how to name your logOS
#                    trees; about an hour)
#   make screenshot  a picture of Logisim's window with both digits lit (needs xvfb-run)
#   make fpga        Logisim's FPGA flow for the Tang Nano 20K, without loading the board
#                    (see fpga.sh; needs the Gowin tools)
#   make clean       delete what the tests made
#
# Everything a test makes is in build/. The tests need Java 21, the RISC-V compiler, Python 3
# with pexpect and, for the gdb test, gdb-multiarch (or another RISC-V gdb: make test GDB=...).

CIRCUIT ?= ../computer.circ
LOGISIM_VERSION = 5.0.10
LOGISIM_JAR ?= ../../logisim-evolution-ucd-$(LOGISIM_VERSION)-all.jar
RISCV_TOOL_PREFIX ?= riscv64-unknown-elf-
PYTHON ?= python3
GDB ?= $(or $(shell command -v gdb-multiarch),$(shell command -v riscv64-elf-gdb),$(shell command -v riscv64-unknown-elf-gdb),gdb)
GDB_PORT ?= 3333

PROGRAMS = digits kbdirq timer show
IMAGES = $(PROGRAMS:%=build/%.txt)

all: $(IMAGES)

build/%.o: %.S computer.h
	@mkdir -p build
	$(RISCV_TOOL_PREFIX)gcc -march=rv32im_zicsr -mabi=ilp32 -g -c $< -o $@

build/%: build/%.o build/lib.o link.lds
	$(RISCV_TOOL_PREFIX)ld -nostdlib -T link.lds -o $@ build/lib.o $<
	$(RISCV_TOOL_PREFIX)objdump -S $@ > $@.asm

# the ROM image: the program's words in hexadecimal, as Logisim loads them
build/%.txt: build/%
	$(RISCV_TOOL_PREFIX)objcopy -O binary $< $<.bin
	echo "v2.0 raw" > $@
	hexdump -v -e '/4 "%08x""\n"""' $<.bin >> $@

.PRECIOUS: build/%.o build/%

test: $(IMAGES)
	$(PYTHON) run_tests.py --jar $(LOGISIM_JAR) --circuit $(CIRCUIT) --gdb $(GDB) --port $(GDB_PORT)

logos:
	./logos.sh $(LOGISIM_JAR) $(CIRCUIT)

screenshot: build/show.txt
	xvfb-run -a -s "-screen 0 3840x1700x24" ./screenshot.sh $(LOGISIM_JAR) $(CIRCUIT)

fpga:
	./fpga.sh $(LOGISIM_JAR) $(CIRCUIT)

clean:
	rm -rf build

.PHONY: all test logos screenshot fpga clean
