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

/* returns 1 if a key had been pressed on the keyboard, or 0 otherwise */
int key_pressed()
{
   return *RCR;
}

/* Input Finite State Machine */
enum
{
   FSM_WAITING_FOR_INPUT,
   FSM_READING_X,
   FSM_READING_Y
};

/* global (UNINITIALIZED!) variable for the state of input FSM */
int input_state;

/* global (UNINITIALIZED!) variables for the bouncing dot coordinates */
int x;
int y;

void main()
{
   // initial position of the dot
   x = 10;
   y = 10;

   // initialise input FSM state
   input_state = FSM_WAITING_FOR_INPUT;

   // speed of dot movement along X and Y axes
   int dx = 1, dy = -1;

   // temporary variables for computing next x and y coords
   int new_x, new_y;

   // temporary variable for accumulating new values for x and y enterd by user
   int inp_x, inp_y;

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

      /* check keyboard and read new coordinates if the user typed something */
      switch (input_state)
      {
         int key;

      case FSM_WAITING_FOR_INPUT:
         if (*RCR == 0)
            break;
         input_state = FSM_READING_X;
         inp_x = 0;
         // fall through to process first digit of inp_x

      case FSM_READING_X:
         if (*RCR == 0)
            break;
         key = *RDR;
         *TTY = key;
         if ((key >= '0') && (key <= '9'))
         {
            inp_x = inp_x * 10 + (key - '0');
            break;
         }
         else
         {
            input_state = FSM_READING_Y;
            inp_y = 0;
            // fall through to process first digit of inp_y
         }

      case FSM_READING_Y:
         if (*RCR == 0)
            break;
         key = *RDR;
         *TTY = key;
         if ((key >= '0') && (key <= '9'))
         {
            inp_y = inp_y * 10 + (key - '0');
            break;
         }
         else
         {
            input_state = FSM_WAITING_FOR_INPUT;
            if ((inp_x >= VGA_WIDTH) || (inp_y >= VGA_HEIGHT))
            {
               printstr("New coords out of bounds!\n");
            }
            else
            {
               VGA_PLOT(x, y, 0x000000);           // erase the dot by making it black
               VGA_PLOT(inp_x, inp_y, DOT_COLOUR); // paint it in new coordinates
               x = inp_x;
               y = inp_y;
            }
         }
      }
   }
}
