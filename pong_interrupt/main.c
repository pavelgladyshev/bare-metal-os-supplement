/*
 * Example software running in Logisim RISC-V Computer System model by Pavel Gladyshev
 * licensed under Creative Commons Attribution International license 4.0
 *
 * This example shows how graphics display can be used to dsisplay a dot bouncing
 * off the screen borders.
 *
 * the position of the ball can be changed by typing new x,y coordinates on the keyboard
 * and pressing Enter key. Coordinate values are in 0..63 range. The origin (0,0) is in
 * the top left corner of the vga display
 *
 */

#include "vga.h"
#include "console.h"
#include "trap.h"

/* global (UNINITIALIZED!) trap frame (to hold the execution context of 
*  the main program while handling interrupts)*/
trap_frame_t trap_frame;

/* program stacks for the C language trap handler code */
int trap_handler_stack[256];

void c_trap_handler(trap_frame_t *tf);
void init_interrupts()
{
   // Configure pointer to the C language trap handler 
   trap_frame.c_trap = (uint32) c_trap_handler;

   // top of the C language trap handler's stack 
   trap_frame.c_trap_sp = (uint32) &trap_handler_stack[255];  

   // write address of the assembly language trap handler into CPU's mtvec register
   // and the address of the trap_frame data structure into CPU's mscratch register
   set_trap_handler(trap_handler,&trap_frame);

   // enable interrupts from external source by setting bit 11 in CPU's mie register
   set_mie(0x800);

   // enable handling of interrupts in CPU by setting bit 8 in CPU's mstatus register
   enable_interrupts();
}

/*
 * Macro VGA_PLOT(X,Y,COLOUR) plots a dot with the specified colour at (X,Y)
 * All macro parameters in the expression are surrounded by brackets to avoid
 * unintended operator precedence problems
 */
#define VGA_PLOT(X, Y, COLOUR) ((VGA)[((Y) * (VGA_WIDTH)) + (X)] = (COLOUR))

/* Colour of the bouncing dot 0xRRGGBB */
#define DOT_COLOUR (0xFFFFFF)

/* print string to TTY */
void printstr(char *str)
{
   while (*str)
      *TTY = *str++;
}

/* global (UNINITIALIZED!) variables for the bouncing dot coordinates */
int x;
int y;
int inp_ready;
char inp_buff[256];
int inp_index;

/* read integer from inp_buff[] starting from inp_index */
int scanint()
{
   int res,chr;
   for (res = 0;inp_index < sizeof(inp_buff);)
   {
      chr = inp_buff[inp_index++];
      if ((chr == 0) || (chr < '0') || (chr > '9'))
         break;
      res = res * 10 + (chr - '0');
   }
   return res;
}

void main()
{
   // initiall position of the dot
   x = 10;
   y = 10;

   // speed of dot movement along X and Y axes
   int dx = 1, dy = -1;

   // temporary variables for computing next x and y coords
   int new_x, new_y;

   // print instructions on TTY
   printstr("input new coords as X,Y<Enter>\n");

   // initialise user input variables
   inp_index = 0;
   inp_ready = 0;

   // initialise interrup handling
   init_interrupts();

   // plot white dot
   VGA_PLOT(x, y, DOT_COLOUR);


   // forever: 1) calculate new dot position
   // 2) if new position is outside boundaries
   //    change directions, recalculate positions
   // 3) erase dot in the old position
   // 4) plot the dot in the new position
   for (;;)
   {   
      new_x = x + dx;
      new_y = y + dy;

      if ((new_x < 0) || (new_x >= VGA_WIDTH))
      {
         dx = -dx;       // bounce along X
         new_x = x + dx; // recalculate
      }

      if ((new_y < 0) || (new_y >= VGA_HEIGHT))
      {
         dy = -dy;       // bounce along y
         new_y = y + dy; // reclaculate
      }

      VGA_PLOT(x, y, 0x000000);           // erase the dot by making it black
      VGA_PLOT(new_x, new_y, DOT_COLOUR); // paint it in new coordinates

      x = new_x;
      y = new_y; // remember new coordinates

      // check if new co-ordinates had been entered
      
      disable_interrupts();  // block trap handler from changing data
                             // while we are working on it
      
      if (inp_ready) {

         inp_index = 0;      // reset inp_index to the start of inp_buff[]
         new_x = scanint();
         new_y = scanint();
         if ((new_x >= VGA_WIDTH) || (new_y >= VGA_HEIGHT))
         {
            printstr("New coords out of bounds!\n");
         }
         else
         {
            VGA_PLOT(x, y, 0x000000);           // erase the dot by making it black
            VGA_PLOT(new_x, new_y, DOT_COLOUR); // paint it in new coordinates
            x = new_x;
            y = new_y;
         }
         inp_index = 0;
         inp_ready = 0;
      }

      enable_interrupts();   // re-enable interrupt handling

   }
}


/*
 * Trap handler written in C language (jumped to from 
 * the assembly language trap_handler)
 */
void c_trap_handler(trap_frame_t *tf) {

   int key;

   if (inp_index < (sizeof(inp_buff)-1)) {

      while ((*RCR != 0)) {
      
         key = *RDR;   
         *TTY = key; // echo typed character to TTY display

         if ((key != '\n')&&(inp_index < (sizeof(inp_buff)-1))) {
            inp_buff[inp_index++] = key;
         } else {
            inp_buff[inp_index]='\0';
            inp_ready = 1;
            break;
         }
      }
   }
      
   while (*RCR != 0)    
      key = *RDR; 

   trap_ret(tf);   // restore main program's execution context and return to it
}
