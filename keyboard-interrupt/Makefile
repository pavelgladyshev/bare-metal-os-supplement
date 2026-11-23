# Makefile for software running in Logisim RISC-V Computer System model by Pavel Gladyshev
# licensed under Creative Commons Attribution International license 4.0
#
# This Makefile is designed to be used in Ubuntu Linux. Make sure that all required 
# software packages are installed before running this file. To install necessary packages 
# in Ubuntu Linux, simply run the following command:
#
# sudo apt install build-essential binutils-riscv64-unknown-elf gcc-riscv64-unknown-elf
#
# To build the application, cd into the folder with this file and run make
#
# If you want to change the name of the executable or add/remove source files in this project,
# edit the Application-specific detail section below. 
#
#   make             build the ELF file, the listing (.asm) and the ROM image (.txt)
#   make run         run the program in Logisim's text mode, the fast way (Ctrl-C stops it)
#   make gui         run it in Logisim's window
#   make debug       text mode, with the CPU's GDB server on: the CPU waits for gdb
#   make gui-debug   the same in the window
#   make gdb         in another terminal: connect gdb to it, with the program's symbols
#   make list        the program's instructions with their addresses and source lines
#   make logisim     fetch Logisim (the other targets do it when it is missing)
#   make clean       delete what the builds made

# --- Application-specific detail ----

# name of the executable file
EXECUTABLE = keyboard-interrupt

# RISC-V instruction set architecture: this program uses the CSR instructions (Zicsr)
RISCV_ISA = rv32im_zicsr

# list of all *object* files that must be produced and linked together into the executable.
# for *each* object file in this list there must be a corresponding C (.c) or Assembly (.S or .s) source file
OBJECT_FILES = interrupt_kbd.o

# list of all header files (.h) and, possibly, other data files *included* into the source code files
# via .include or #include directives
#HEADER_FILES = 

# the panel of CSRs below the CPU's registers in Logisim's window: none, machine or supervisor
CSR_PANEL = machine

# the path from this folder to the top folder of the supplement (the circuit, tools and Logisim are there)
SUPPLEMENT = ..

# --- Common part: the same in every project (make check-template, in the top folder, checks it) ---

# name of the binary file to hold .text and other executable sections that will be placed in ROM
ROM_IMAGE ?= $(EXECUTABLE)-rom

# name of the Logisim ROM image file that will be produced from the binary file
ROM_IMAGE_TXT = $(ROM_IMAGE).txt

# what will be built, if make command is run without parameters
.DEFAULT_GOAL = $(ROM_IMAGE_TXT)

# Tool name prefix
RISCV_TOOL_PREFIX?=riscv64-unknown-elf-

# RISC-V instruction set architecture to use when compiling the program (RV32IM by default).
# A program that uses CSR instructions (interrupts) needs rv32im_zicsr: set it above, next to EXECUTABLE
RISCV_ISA ?= rv32im

# RISC-V function calling convention to use when compiling the program (ILP32 by default)
RISCV_ABI ?= ilp32

# Additional command line options for GCC
CFLAGS=-Wno-builtin-declaration-mismatch

# Linker script file to use when producing the executable
LINKER_SCRIPT_FILE=logisim.lds

# rule and command to compile C files
%.o : %.c
	${RISCV_TOOL_PREFIX}gcc -O -march=$(RISCV_ISA) -mabi=$(RISCV_ABI) -mcmodel=medany -g -c $(CFLAGS) $< -o $@

# rule and command to process .S assembly files using GNU C compiler (.S files may contain C-style #include and #define statements)
%.o : %.S
	${RISCV_TOOL_PREFIX}gcc -O -march=$(RISCV_ISA) -mabi=$(RISCV_ABI) -mcmodel=medany -g -c $(CFLAGS) $< -o $@
	
# rule and command to process .s assembly files using GNU Assembler (.s files must use pure assembly language syntax)
%.o : %.s
	${RISCV_TOOL_PREFIX}as -march=$(RISCV_ISA) -mabi=$(RISCV_ABI) -g $< -o $@
	
# rule that says that all object files need to be recompiled if any of the header files change
$(OBJECT_FILES) : $(HEADER_FILES)

# rule and commands to generate executable file (ELF), disassemble it into .asm file, create linker MAP, and symbol table
$(EXECUTABLE) : $(OBJECT_FILES) 
	${RISCV_TOOL_PREFIX}ld -nostdlib -o $(EXECUTABLE) -Map $(EXECUTABLE).map -T $(LINKER_SCRIPT_FILE) $^
	${RISCV_TOOL_PREFIX}objdump -S $(EXECUTABLE) > $(EXECUTABLE).asm
	${RISCV_TOOL_PREFIX}nm $(EXECUTABLE) > $(EXECUTABLE).sym

# rule and command to extract all code and constant data sections from the ELF executable and place them into a plain binary file (ROM_IMAGE)
$(ROM_IMAGE) : $(EXECUTABLE)
	${RISCV_TOOL_PREFIX}objcopy --only-section .init --only-section .text --only-section .rodata --only-section .srodata --only-section .data --only-section .sdata --only-section .text.* --only-section .rodata.* --only-section .srodata.* --only-section .data.* --only-section .sdata.*  --output-target binary $(EXECUTABLE) $(ROM_IMAGE)

# rule and commands to convert the binary ROM image into .txt file that can be loaded into Logisim ROM component 
$(ROM_IMAGE_TXT) : clean $(ROM_IMAGE)
	echo "v2.0 raw" >$(ROM_IMAGE_TXT)
	hexdump -v -e '/4 "%08x""\n"""' $(ROM_IMAGE) >>$(ROM_IMAGE_TXT)

# command to delete all executable and object files and their derivatives as a way of forcing complete rebuild of the project
clean: 
	rm -f $(OBJECT_FILES) $(ROM_IMAGE_TXT) $(ROM_IMAGE) $(EXECUTABLE) $(EXECUTABLE).map $(EXECUTABLE).sym $(EXECUTABLE).asm 
	rm -rf $(BUILD_DIR)

# ------------------------------------
# Running the program in Logisim
#
# make run builds the program, puts its ROM image into a copy of the circuit CIRCUIT (in the build
# folder, with tools/mkcircuit.py) and runs that copy. In text mode the terminal you type in is the
# computer's TTY and keyboard. CSR_PANEL (above) is the panel of CSRs that the window shows below the
# CPU's registers: none, machine or supervisor.
# ------------------------------------

# the circuit to run the program in, and the folder for the circuits made from it
CIRCUIT ?= $(SUPPLEMENT)/computer/computer.circ
BUILD_DIR = build
MKCIRCUIT = $(SUPPLEMENT)/tools/mkcircuit.py
PYTHON ?= python3

# Logisim Evolution UCD, fetched from its releases (make logisim).
# Another one: make run LOGISIM_JAR=/its/path/logisim-evolution-ucd-5.0.10-all.jar
LOGISIM_VERSION = 5.0.10
LOGISIM_JAR ?= $(SUPPLEMENT)/logisim-evolution-ucd-$(LOGISIM_VERSION)-all.jar
LOGISIM_URL = https://github.com/pavelgladyshev/logisim-evolution-ucd/releases/download/v$(LOGISIM_VERSION)/logisim-evolution-ucd-$(LOGISIM_VERSION)-all.jar

logisim: $(LOGISIM_JAR)

$(LOGISIM_JAR):
	curl -fL --progress-bar -o $@.part $(LOGISIM_URL) && mv $@.part $@

# the circuit with the program in its ROM, and the same with the CPU's GDB server switched on
$(BUILD_DIR)/$(EXECUTABLE).circ: $(ROM_IMAGE_TXT) $(CIRCUIT) $(MKCIRCUIT)
	mkdir -p $(BUILD_DIR)
	$(PYTHON) $(MKCIRCUIT) $(CIRCUIT) $@ --rom $(ROM_IMAGE_TXT) --csr-panel $(CSR_PANEL)

$(BUILD_DIR)/$(EXECUTABLE)-debug.circ: $(ROM_IMAGE_TXT) $(CIRCUIT) $(MKCIRCUIT)
	mkdir -p $(BUILD_DIR)
	$(PYTHON) $(MKCIRCUIT) $(CIRCUIT) $@ --rom $(ROM_IMAGE_TXT) --csr-panel $(CSR_PANEL) --debug $(GDB_PORT)

# Text mode: the TTY is this terminal, and the simulation runs much faster than in the window.
run: logisim $(BUILD_DIR)/$(EXECUTABLE).circ
	java -jar $(LOGISIM_JAR) $(BUILD_DIR)/$(EXECUTABLE).circ --tty raw

# The window. On Windows (WSL), Java for Windows, when it is on the PATH, gives a native window;
# without it, Linux's Java shows the window through WSLg
JAVA_GUI = $(if $(shell command -v javaw.exe),javaw.exe,java)

gui: logisim $(BUILD_DIR)/$(EXECUTABLE).circ
	$(JAVA_GUI) -jar $(LOGISIM_JAR) $(BUILD_DIR)/$(EXECUTABLE).circ

# The debugger. Logisim's RV32IM CPU has a GDB server. make debug starts the program in text mode
# with the server switched on, in a copy of the circuit, and the CPU waits for a debugger; make gdb,
# in another terminal, connects a RISC-V gdb to it with the program's symbols (then: break main,
# continue). Another gdb: make gdb GDB=/its/path/riscv64-elf-gdb
GDB_PORT = 3333
GDB ?= $(or $(shell command -v gdb-multiarch),$(shell command -v riscv64-elf-gdb),$(shell command -v riscv64-unknown-elf-gdb),gdb)

debug: logisim $(BUILD_DIR)/$(EXECUTABLE)-debug.circ
	java -jar $(LOGISIM_JAR) $(BUILD_DIR)/$(EXECUTABLE)-debug.circ --tty raw

gui-debug: logisim $(BUILD_DIR)/$(EXECUTABLE)-debug.circ
	$(JAVA_GUI) -jar $(LOGISIM_JAR) $(BUILD_DIR)/$(EXECUTABLE)-debug.circ

# gdb must be told that the program is bare metal (osabi none): otherwise it takes it for a
# Linux program and steps by planting a breakpoint after the instruction, which fails at mret.
# This rule needs the ELF file only, so that it does not rebuild the program that is running.
gdb: $(EXECUTABLE)
	$(GDB) -q -ex 'set architecture riscv:rv32' -ex 'set osabi none' -ex 'target remote localhost:$(GDB_PORT)' $(EXECUTABLE)

# the program with the addresses of its instructions beside the source lines
list: $(EXECUTABLE)
	${RISCV_TOOL_PREFIX}objdump -S $(EXECUTABLE)

.PHONY: clean logisim run gui debug gui-debug gdb list

# --- End of the common part ---
