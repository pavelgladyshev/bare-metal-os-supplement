# Builds every example project of the supplement, with the RISC-V compiler this computer has.
#
#   make          build all the projects
#   make clean    delete what the builds made
#   make check    say which tools this computer has
#   make check-template   say whether the projects' Makefiles still have template/Makefile's common part
#
# Each project also builds on its own: cd into its folder and type make. The projects'
# Makefiles name Ubuntu's compiler (riscv64-unknown-elf-); with Homebrew's on a Mac, type
#   make RISCV_TOOL_PREFIX=riscv64-elf-
# there, or build from this folder, which finds the compiler by itself, as logOS does.

ifndef RISCV_TOOL_PREFIX
  ifneq ($(shell command -v /opt/homebrew/bin/riscv64-elf-gcc),)
    # Homebrew on a Mac with Apple silicon
    RISCV_TOOL_PREFIX := /opt/homebrew/bin/riscv64-elf-
  else ifneq ($(shell command -v riscv64-elf-gcc),)
    # Homebrew on an Intel Mac, Arch Linux
    RISCV_TOOL_PREFIX := riscv64-elf-
  else
    # Ubuntu, Debian, Windows (Ubuntu on WSL): gcc-riscv64-unknown-elf
    RISCV_TOOL_PREFIX := riscv64-unknown-elf-
  endif
endif

LOGISIM_PROJECTS = template simple-asm simple-c pong/blocking pong/fsm pong/coroutines pong_interrupt \
                   keyboard-polled keyboard-interrupt multitasking multitasking-racing multitasking-synchronised
# assembly/ holds several programs with one Makefile: PROG names the program
ASSEMBLY_PROGRAMS = example1 memory led echo max looping subroutine sort-word-array
QEMU_PROJECTS    = smp-simple-assembly smp-boxes smp-boxes-synchronised smp-counter-litmus
PROJECTS         = $(LOGISIM_PROJECTS) $(QEMU_PROJECTS)

.PHONY: all clean check check-template assembly $(PROJECTS)

all: assembly $(PROJECTS)

$(PROJECTS):
	$(MAKE) -C $@ RISCV_TOOL_PREFIX=$(RISCV_TOOL_PREFIX)

assembly:
	for p in $(ASSEMBLY_PROGRAMS); do $(MAKE) -C assembly PROG=$$p RISCV_TOOL_PREFIX=$(RISCV_TOOL_PREFIX) || exit 1; done

clean:
	for p in $(PROJECTS); do $(MAKE) -C $$p clean; done
	for p in $(ASSEMBLY_PROGRAMS); do $(MAKE) -C assembly PROG=$$p clean; done

check:
	@$(RISCV_TOOL_PREFIX)gcc --version | head -1 || echo "NOT OK  no RISC-V compiler ($(RISCV_TOOL_PREFIX)gcc)"
	@java -version 2>&1 | head -1 || echo "NOT OK  no Java (Logisim needs 21 or later)"
	@qemu-system-riscv64 --version | head -1 || echo "note    no qemu-system-riscv64 (needed for the smp- projects only)"

# Every Logisim project's Makefile has template/Makefile's common part, and the projects that run
# on the one computer have the template's linker script unchanged. The Pong games have linker
# scripts of their own: their computer has less RAM.
ONE_COMPUTER = simple-asm simple-c assembly keyboard-polled keyboard-interrupt multitasking \
               multitasking-racing multitasking-synchronised
check-template:
	tools/check_template.sh $(LOGISIM_PROJECTS) assembly -- $(ONE_COMPUTER)
