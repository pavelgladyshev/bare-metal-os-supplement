
      # This program demonstrates method of input
      # using peripheral device "polling"
      #
      # Program waits for the user to press a key
      # in KEYBOARD window, reads the key code from a 
      # memory-mapped register, and sends it to DISPLAY 
      # window by writing it to a different memory-mapped
      # register
      #
      # Before running this program do:
      #
      # 1. Go to Tools -> "Keyboard and Display MMIO Simulator"
      # 2. Click "Connect to Program" button
      # 3. Untick DAD tick box.
      #
      # Idea of polling: peripheral device (keyboard) has two
      # memory mapped registers: "control" register
      # and "data" register. Control register 
      # is a bit like a washing machine control panel:
      # some bits act like buttons, some bits act as
      # indicator lights
      #
      # algorithm: keep reading content of control
      # register while "new data arrived" bit (0) is 0
      # once that bit becomes 1, the new data can be
      # read from the keyboard data regiser.  The act of
      # reading the data clears the "new data arrived" bit
      # in control register.
      
      .data 
digits: 
      .byte 0x3f,0x06,0x5b,0x4f
      
      .text
main: 
      li s0,0xffff0000   # receiver control register
      li s1,0xffff0004   # received data register
      li s2,0xffff000c   # transmitter data register
      
      li s3,0xffff0010   # right-most 7-segment display
      la s4,digits       # array of digit codes
      li s5,0            # index of the digit to be displayed
loop:
      lw t0,0(s0)        # read content of receiver control register
      beq t0,zero,skip   # if bit 0 is 0, skip to 7-segment display processing
      
      # new data has arrived      
      lw t1,(s1)         # read content of receiver data register
      sw t1,(s2)         # send it to transmitter data register
      
skip:
      # display next digit
      add s6,s5,s4       # calc pointer to the current digit
      lbu t0,0(s6)       # load current digit code
      sb t0,0(s3)        # write it to display
      addi s5,s5,1       # increment digit array index by 1
      andi s5,s5,0x3     # wrap index around back to 0 if it becomes 4
      
      j loop             # keep looping
      
      
