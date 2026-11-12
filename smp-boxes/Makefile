# Makefile for compiling and running programs on multi-hart RISC-V SMP computer
# emulated in QEMU. Author: Pavel Gladyshev. Licensed under Creative Commons 
# Attribution International license 4.0
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

# --- Application-specific detail ----

# name of the executable file
EXECUTABLE = smp-example

# list of all *object* files that must be produced and linked together into the executable.
# for *each* object file in this list there must be a corresponding C (.c) or Assembly (.S or .s) source file
OBJECT_FILES = crt0.o main.o printf.o spinlock.o

# list of all header files (.h) and, possibly, other data files *included* into the source code files
# via .include or #include directives
#HEADER_FILES = 

# ------------------------------------

# what will be built, if make command is run without parameters
.DEFAULT_GOAL = $(EXECUTABLE)

# Tool name prfix
RISCV_TOOL_PREFIX=riscv64-unknown-elf-

# RISC-V instruction set architecture to use when compiling the program (RV32IM by default)
RISCV_ISA=rv64g

# RISC-V function calling convention to use when compiling the program (ILP32 by default)
RISCV_ABI=lp64

# Additional command line options for GCC
CFLAGS=-DQEMU20180 -Wno-builtin-declaration-mismatch

# Linker script file to use when producting the executable
LINKER_SCRIPT_FILE=qemu.lds

# QEMU executable to use
QEMU_APP=qemu-system-riscv64

# Number of CPUS to emulate (try changing this!)
ifndef CPUS
CPUS := 3 
endif

# QEMU options to show displays
#QEMU_DISPLAYS=-serial stdio
# QEMU options to not show displays
QEMU_DISPLAYS=-nographic

# rule and command to compile C files
%.o : %.c
	${RISCV_TOOL_PREFIX}gcc -O -march=$(RISCV_ISA) -mabi=$(RISCV_ABI) -mcmodel=medany -g -c $(CFLAGS) $< -o $@

# rule and command to process .S assembly files using GNU C compiler (.S files may contain C-style #include and #define statements)
%.o : %.S
	${RISCV_TOOL_PREFIX}gcc -O -march=$(RISCV_ISA) -mabi=$(RISCV_ABI) -mcmodel=medany -g -c $(CFLAGS) $< -o $@
	
# rule and command to process .s assembly files using GNU Assembler (.s files must use pure assembly language syntax)
%.o : %.s
	${RISCV_TOOL_PREFIX}as -march=$(RISCV_ISA) -mabi=$(RISCV_ABI) -g -c $< -o $@
	
# rule that says that all object files need to be recompiled if any of the header files change
$(OBJECT_FILES) : $(HEADER_FILES)

# rule and commands to generate executable file (ELF), disassemble it into .asm file, create linker MAP, and symbol table
$(EXECUTABLE) : $(OBJECT_FILES) 
	${RISCV_TOOL_PREFIX}ld -nostdlib -o $(EXECUTABLE) -Map $(EXECUTABLE).map -T $(LINKER_SCRIPT_FILE) $^
	${RISCV_TOOL_PREFIX}objdump -S $(EXECUTABLE) > $(EXECUTABLE).asm
	${RISCV_TOOL_PREFIX}nm $(EXECUTABLE) > $(EXECUTABLE).sym

# command to delete all executable and object files and their derivatives as a way of forcing complete rebuild of the project
clean: 
	rm -f $(OBJECT_FILES) $(EXECUTABLE) $(EXECUTABLE).map $(EXECUTABLE).sym $(EXECUTABLE).asm 

# run compiled program in qemu, redirect MMIO Keybard and Console to use command line.
qemu: $(EXECUTABLE)
	@echo To exit QEMU running in -nographic mode, press \'Crtl-A\' and then \'x\' 
	$(QEMU_APP) -machine virt -kernel $(EXECUTABLE) -smp $(CPUS) -bios none $(QEMU_DISPLAYS) 

# start compiled program in qemu and freeze it until GDB connects at localhost:1234
qemu-gdb: $(EXECUTABLE)
	@echo To exit QEMU running in -nographic mode, press \'Crtl-A\' and then \'x\' 
	$(QEMU_APP) -s -S -machine virt -kernel $(EXECUTABLE) -smp $(CPUS) -bios none $(QEMU_DISPLAYS)
