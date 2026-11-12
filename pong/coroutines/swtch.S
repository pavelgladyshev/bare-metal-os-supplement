# Context switching function
# void swtch(context *current, context *next)

	.text
	.globl swtch
swtch:
        mv t0,a0
        mv t1,a1
        
        sw ra, 0(t0)
	sw sp, 4(t0)
        sw gp, 8(t0)
        sw tp, 12(t0)
        sw s0, 16(t0)
        sw s1, 20(t0)
        sw a0, 24(t0)
        sw a1, 28(t0)
        sw a2, 32(t0)
        sw a3, 36(t0)
        sw a4, 40(t0)
        sw a5, 44(t0)
        sw a6, 48(t0)
        sw a7, 52(t0)
        sw s2, 56(t0)
        sw s3, 60(t0)
        sw s4, 64(t0)
        sw s5, 68(t0)
        sw s6, 72(t0)
        sw s7, 76(t0)
        sw s8, 80(t0)
        sw s9, 84(t0)
        sw s10, 88(t0)
        sw s11, 92(t0)

        lw ra, 0(t1)
        lw sp, 4(t1)
        lw gp, 8(t1)
        lw tp, 12(t1)
        lw s0, 16(t1)
        lw s1, 20(t1)
        lw a0, 24(t1)
        lw a1, 28(t1)
        lw a2, 32(t1)
        lw a3, 36(t1)
        lw a4, 40(t1)
        lw a5, 44(t1)
        lw a6, 48(t1)
        lw a7, 52(t1)
        lw s2, 56(t1)
        lw s3, 60(t1)
        lw s4, 64(t1)
        lw s5, 68(t1)
        lw s6, 72(t1)
        lw s7, 76(t1)
        lw s8, 80(t1)
        lw s9, 84(t1)
        lw s10, 88(t1)
        lw s11, 92(t1)

        ret

