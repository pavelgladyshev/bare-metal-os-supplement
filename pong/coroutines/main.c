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
#include "coroutines.h"

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

/* global (UNINITIALIZED!) task contexts for dot bouncer and coordinate reader*/
context main_context;
context bouncer_context;
context reader_context;

/* program stacks for dot bouncer and coordinate reader tasks */
int bouncer_stack[256];
int reader_stack[256];

void bouncer_task();
void reader_task();

void main()
{
   bouncer_context.sp = &(bouncer_stack[255]); // points to the last element in bouncer stack
   bouncer_context.ra = bouncer_task;
   reader_context.sp = &(reader_stack[255]); // points to the last element in bouncer stack
   reader_context.ra = reader_task;
   swtch(&main_context, &bouncer_context); // start bouncer task
}

void bouncer_task()
{
   // initiall position of the dot
   x = 10;
   y = 10;

   // speed of dot movement along X and Y axes
   int dx = 1, dy = -1;

   // temporary variables for computing next x and y coords
   int new_x, new_y;

   // plot white dot
   VGA_PLOT(x, y, DOT_COLOUR);

   // print instructions on TTY
   printstr("input new coords as X,Y<Enter>\n");

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

      if (*RCR != 0)
      {
         swtch(&bouncer_context, &reader_context);
      }
   }
}

/* read integer from keyboard */
int readint()
{
   int res, key;
   for (res = 0;;)
   {
      while (*RCR == 0)
      {
         swtch(&reader_context, &bouncer_context);
      };
      key = *RDR;
      *TTY = key;
      if ((key < '0') || (key > '9'))
         break;
      res = res * 10 + (key - '0');
   }
   return res;
}

void reader_task()
{
   int new_x, new_y;
   new_x = readint();
   new_y = readint();
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
}
