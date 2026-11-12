/* Store buffering: can both harts read 0? (illustration) */
void putstr(const char *s);
void putnum(unsigned n);
void barrier(int *round);

#define N 200000

volatile int x[N], y[N];      /* N pairs of flags, all 0 at the start */
volatile int r0[N], r1[N];    /* what hart 0 and hart 1 read          */

void main(int hart)
{
    int round = 0;
    for (int fenced = 0; fenced < 2; fenced++) {
        if (hart == 0)
            for (int i = 0; i < N; i++)
                x[i] = y[i] = 0;
        barrier(&round);
        for (int i = 0; i < N; i++) {
            if (hart == 0) {
                x[i] = 1;                       /* store my flag    */
                if (fenced) asm volatile("fence rw, rw" ::: "memory");
                r0[i] = y[i];                   /* load the other's */
            } else {
                y[i] = 1;
                if (fenced) asm volatile("fence rw, rw" ::: "memory");
                r1[i] = x[i];
            }
        }
        barrier(&round);
        if (hart == 0) {
            int both_zero = 0;
            for (int i = 0; i < N; i++)
                if (r0[i] == 0 && r1[i] == 0)
                    both_zero++;
            putstr(fenced ? "fence rw,rw: " : "no fence:    ");
            putnum(both_zero);
            putstr(" of 200000 pairs read 0 and 0\n");
        }
    }
}
