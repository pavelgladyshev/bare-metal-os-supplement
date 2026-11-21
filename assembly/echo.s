        .text
        li   t0, 0xffff0000   # base address of the keyboard/terminal registers
wait:   lw   t1, 4(t0)        # RCR: is a key waiting?
        beq  t1, zero, wait   # no: ask again
        lw   t2, 8(t0)        # RDR: read the key (this takes it out of the keyboard's buffer)
        sw   t2, 12(t0)       # TDR: print it
        j    wait
