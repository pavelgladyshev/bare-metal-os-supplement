/*
 * Example software running in SMP RISC-V Simulated in QEMU. Author: Pavel Gladyshev
 * licensed under Creative Commons Attribution International license 4.0
 *
 * This is an example of C program, which causes race conditions in multiprocessing
 * execution. At the high level the algorithm is as follows:
 * 
 * 1. Scan through the integer array boxes[] until the first non-zero element is found 
 *    (let's call it boxes[i]).
 * 
 * 2. Runs an empty loop (an imitation of doing some work in a real-world app) for 
 *    the amount of iterations specified in boxes[i].
 * 
 * 3. Set boxes[i]=0 indicating that boxes[i] has been "processed"
 * 
 */

#include "spinlock.h"
int boxes[4]={3,3,3,3}; 

struct spinlock boxes_lock = {.locked = 0, .name = "boxes_lock"}; 

int printf(char *fmt, ...);

void main()
{
    int i = 0;
    acquire(&boxes_lock);
    while(boxes[i]==0) i++;           // 1. scan through boxes array until first non-zero element
    for (int x=boxes[i]; x>0; x--);   // 2. run empty loop for boxes[i] iterations (imitating doing some work)
    boxes[i]=0;                       // 3. set boxes[0]=0 signalling that it has been "processed"
    release(&boxes_lock); 
    // each CPU hart prints the state of boxes[] array after processing
    printf("boxes: %d, %d, %d, %d\n",boxes[0],boxes[1],boxes[2],boxes[3]);
}
