# Builds every example project of the supplement, with the RISC-V compiler this computer has.
#
#   make          build all the projects
#   make clean    delete what the builds made
#   make check    say which tools this computer has
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

LOGISIM_PROJECTS = simple-asm simple-c pong/blocking pong/fsm pong/coroutines pong_interrupt
QEMU_PROJECTS    = smp-simple-assembly smp-boxes smp-boxes-synchronised smp-counter-litmus
PROJECTS         = $(LOGISIM_PROJECTS) $(QEMU_PROJECTS)

.PHONY: all clean check $(PROJECTS)

all: $(PROJECTS)

$(PROJECTS):
	$(MAKE) -C $@ RISCV_TOOL_PREFIX=$(RISCV_TOOL_PREFIX)

clean:
	for p in $(PROJECTS); do $(MAKE) -C $$p clean; done

check:
	@$(RISCV_TOOL_PREFIX)gcc --version | head -1 || echo "NOT OK  no RISC-V compiler ($(RISCV_TOOL_PREFIX)gcc)"
	@java -version 2>&1 | head -1 || echo "NOT OK  no Java (Logisim needs 21 or later)"
	@qemu-system-riscv64 --version | head -1 || echo "note    no qemu-system-riscv64 (needed for the smp- projects only)"
