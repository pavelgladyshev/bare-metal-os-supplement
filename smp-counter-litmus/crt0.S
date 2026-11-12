# Start-up code for two harts on QEMU's virt machine (illustration).
        .section .init
        .globl _start
_start:                       # every hart starts here, at 0x80000000
        csrci mstatus, 8          # interrupts off (they are off after reset anyway)
        csrr  t0, mhartid         # which hart am I?
        li    t1, 1
        bgtu  t0, t1, park        # only harts 0 and 1 take part
        la    sp, __stack_top
        slli  t1, t0, 12          # each hart gets its own 4 KB stack
        sub   sp, sp, t1
        mv    a0, t0              # main(hartid)
        call  main
park:
        wfi                       # other harts, and harts that have finished, wait here
        j     park
