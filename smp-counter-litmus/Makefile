# Makefile for two programs that run on two harts of QEMU's virt machine (RV32IMA):
# counter (four ways of incrementing a shared counter) and litmus (store-buffer reordering).
# Author: Pavel Gladyshev. Licensed under Creative Commons Attribution International license 4.0
#
#   make               builds both programs
#   make run-counter   runs counter in QEMU (Ctrl-A, then x, leaves QEMU)
#   make run-litmus    runs litmus in QEMU

# Tool name prefix (Homebrew on a Mac: make RISCV_TOOL_PREFIX=riscv64-elf-)
RISCV_TOOL_PREFIX=riscv64-unknown-elf-

CFLAGS = -O -march=rv32ima_zicsr -mabi=ilp32 -mcmodel=medany -ffreestanding -nostdlib -g
QEMU   = qemu-system-riscv32 -machine virt -smp 2 -bios none -nographic

all: counter litmus

counter: crt0.S lib.c counter.c smp.lds
	$(RISCV_TOOL_PREFIX)gcc $(CFLAGS) -T smp.lds -o $@ crt0.S lib.c counter.c

litmus: crt0.S lib.c litmus.c smp.lds
	$(RISCV_TOOL_PREFIX)gcc $(CFLAGS) -T smp.lds -o $@ crt0.S lib.c litmus.c

run-counter: counter
	@echo To exit QEMU running in -nographic mode, press \'Ctrl-A\' and then \'x\'
	$(QEMU) -kernel counter

run-litmus: litmus
	@echo To exit QEMU running in -nographic mode, press \'Ctrl-A\' and then \'x\'
	$(QEMU) -kernel litmus

clean:
	rm -f counter litmus
