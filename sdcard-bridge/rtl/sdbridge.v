// sdbridge: the Tang Nano 20K as a microSD card reader and writer for the computer that it is plugged into.
//
// The card in the board's TF slot is driven by riscvSdBlockStorage, the module that Logisim-evolution (UCD
// edition) uses for its Block Storage component on this board, so that the card is read and written exactly as
// the logOS computer reads and writes it. A small state machine takes the part of the computer's CPU and memory,
// and talks to the host over the board's USB serial port (115200 baud, 8 data bits, no parity, 1 stop bit).
//
// The protocol: every request starts with one command byte; numbers are little-endian.
//   'P'                          -> 'S' 'D' 'B' '1'                       is anybody there?
//   'R' block[4]                 -> 'K' data[512] sum[2]  or  'E'         read a 512-byte block
//   'W' block[4] data[512] sum[2]-> 'K'  or  'E'  or  'C'                 write a block
// sum is the 16-bit sum of the 512 data bytes. 'E': the card failed (or there is none); 'C': the sum of the
// data the board received was wrong, and nothing was written. A request that stops half-way is abandoned after
// half a second, and the board waits for a new command byte.
//
// LEDs (lit when low): 0 the card is working, 1 the last command failed, 5 alive (blinks).
module sdbridge #(
   parameter CLOCK_HZ = 27000000,
   parameter BAUD     = 115200
)(
   input        clk,
   input        uart_rx,
   output       uart_tx,
   output       sd_sck,
   output       sd_mosi,
   output       sd_cs,
   input        sd_miso,
   output [5:0] led
);
   localparam CLKS_PER_BIT = (CLOCK_HZ + BAUD / 2) / BAUD;
   localparam TIMEOUT      = CLOCK_HZ / 2;

   // ------------------------------------------------------------------ the serial port
   wire       rxValid;
   wire [7:0] rxByte;
   reg        txStart = 1'b0;
   reg  [7:0] txByte  = 8'd0;
   wire       txBusy;
   uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) RX (.clk(clk), .rx(uart_rx), .valid(rxValid), .data(rxByte));
   uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) TX (.clk(clk), .start(txStart), .data(txByte), .tx(uart_tx), .busy(txBusy));

   // ------------------------------------------------------------------ the card, as the computer drives it
   // A tick every 4 clocks: the module acts only at a tick, and its block buffer and this memory each answer one
   // clock after they are given an address.
   reg [1:0] tickCount = 2'd0;
   wire      tick = (tickCount == 2'd3);
   always @(posedge clk) tickCount <= tickCount + 2'd1;

   reg  [2:0]  regAddr = 3'd0;
   reg         regRead = 1'b0;
   reg         regWrite = 1'b0;
   reg  [31:0] regData = 32'd0;
   wire [31:0] storageOut, dmaAddr;
   wire        busReq, memRead, memWrite;
   wire [3:0]  be;
   reg         busAck = 1'b0;
   reg  [31:0] memWord = 32'd0;

   riscvSdBlockStorage #(.SLOW_DIV(34), .FAST_DIV(1), .POWER_UP(54000)) STORAGE (
      .clock(clk), .tick(tick), .reset(1'b0), .addr(regAddr), .re(regRead), .we(regWrite && tick),
      .dataIn(regData), .dataOut(storageOut), .busReq(busReq), .busAck(busAck), .memRead(memRead),
      .memWrite(memWrite), .dmaAddr(dmaAddr), .be(be), .memDataIn(memWord),
      .sdSck(sd_sck), .sdMosi(sd_mosi), .sdCs(sd_cs), .sdMiso(sd_miso));

   // the "memory": one block, as four byte lanes, so that the serial side can read and write single bytes
   reg  [7:0] lane0 [0:127];
   reg  [7:0] lane1 [0:127];
   reg  [7:0] lane2 [0:127];
   reg  [7:0] lane3 [0:127];
   reg  [8:0] byteIndex = 9'd0;     // the serial side's byte in the block
   reg        byteWrite = 1'b0;
   wire [6:0] wordAddr = busReq ? dmaAddr[8:2] : byteIndex[8:2];
   always @(posedge clk) begin
      if (tick && memWrite) begin
         lane0[dmaAddr[8:2]] <= storageOut[7:0];
         lane1[dmaAddr[8:2]] <= storageOut[15:8];
         lane2[dmaAddr[8:2]] <= storageOut[23:16];
         lane3[dmaAddr[8:2]] <= storageOut[31:24];
      end else if (byteWrite)
         case (byteIndex[1:0])
            2'd0: lane0[byteIndex[8:2]] <= rxByte;
            2'd1: lane1[byteIndex[8:2]] <= rxByte;
            2'd2: lane2[byteIndex[8:2]] <= rxByte;
            2'd3: lane3[byteIndex[8:2]] <= rxByte;
         endcase
      memWord <= {lane3[wordAddr], lane2[wordAddr], lane1[wordAddr], lane0[wordAddr]};
      if (tick) begin
         if (busReq && !busAck) busAck <= 1'b1;
         else if (!busReq && busAck) busAck <= 1'b0;
      end
   end
   wire [7:0] memByte = (byteIndex[1:0] == 2'd0) ? memWord[7:0]   : (byteIndex[1:0] == 2'd1) ? memWord[15:8] :
                        (byteIndex[1:0] == 2'd2) ? memWord[23:16] : memWord[31:24];

   // ------------------------------------------------------------------ the commands
   localparam S_COMMAND = 5'd0,  S_BLOCK = 5'd1,  S_DATA = 5'd2,  S_SUM = 5'd3,   S_SET_MEM = 5'd4,
              S_SET_BLOCK = 5'd5, S_SET_CMD = 5'd6, S_SETTLE = 5'd7, S_POLL = 5'd8, S_SEND_STATUS = 5'd9,
              S_SEND_DATA = 5'd10, S_SEND_DATA2 = 5'd11, S_SEND_SUM = 5'd12, S_SEND_ID = 5'd13, S_SEND = 5'd14,
              S_WAIT_SEND = 5'd15;

   reg [4:0]  state = S_COMMAND;
   reg [4:0]  afterSend = S_COMMAND;
   reg [7:0]  command = 8'd0;
   reg [31:0] block = 32'd0;
   reg [1:0]  count = 2'd0;
   reg [15:0] sum = 16'd0;
   reg [15:0] sumIn = 16'd0;
   reg [3:0]  settle = 4'd0;
   reg        failed = 1'b0;
   reg        armed = 1'b0;
   reg [24:0] idle = 25'd0;
   reg [24:0] alive = 25'd0;

   wire receiving = (state == S_BLOCK) || (state == S_DATA) || (state == S_SUM);
   assign led = {~alive[24], 3'b111, ~failed, ~(busReq || state == S_POLL)};

   task send(input [7:0] b, input [4:0] next);
      begin txByte <= b; txStart <= 1'b1; afterSend <= next; state <= S_WAIT_SEND; end
   endtask

   always @(posedge clk) begin
      alive     <= alive + 25'd1;
      txStart   <= 1'b0;
      byteWrite <= 1'b0;
      idle      <= rxValid ? 25'd0 : (idle == TIMEOUT[24:0] ? idle : idle + 25'd1);
      if (receiving && idle == TIMEOUT[24:0]) state <= S_COMMAND;
      else case (state)
         S_COMMAND   : if (rxValid) begin
                          command <= rxByte;
                          count   <= 2'd0;
                          if (rxByte == "P") begin count <= 2'd0; state <= S_SEND_ID; end
                          else if (rxByte == "R" || rxByte == "W") state <= S_BLOCK;
                       end
         S_BLOCK     : if (rxValid) begin
                          block <= {rxByte, block[31:8]};
                          count <= count + 2'd1;
                          if (count == 2'd3) begin
                             byteIndex <= 9'd0;
                             sum       <= 16'd0;
                             state     <= (command == "W") ? S_DATA : S_SET_MEM;
                          end
                       end
         S_DATA      : if (rxValid) begin
                          byteWrite <= 1'b1;
                          sum       <= sum + {8'd0, rxByte};
                          if (byteIndex == 9'd511) begin count <= 2'd0; state <= S_SUM; end
                       end else if (byteWrite)
                          byteIndex <= byteIndex + 9'd1;   // after the byte is written at the old index
         S_SUM       : if (rxValid) begin
                          sumIn <= {rxByte, sumIn[15:8]};
                          count <= count + 2'd1;
                          if (count == 2'd1) begin
                             if ({rxByte, sumIn[15:8]} != sum) send("C", S_COMMAND);
                             else state <= S_SET_MEM;
                          end
                       end
         // the computer's driver: memory address, block number, command, then the status until it is done
         // Each register write is set up a clock before the tick at which the module takes it.
         S_SET_MEM   : if (!armed) begin regAddr <= 3'd1; regData <= 32'd0; regWrite <= 1'b1; armed <= 1'b1; end
                       else if (tick) begin armed <= 1'b0; state <= S_SET_BLOCK; end
         S_SET_BLOCK : if (!armed) begin regAddr <= 3'd2; regData <= block; armed <= 1'b1; end
                       else if (tick) begin armed <= 1'b0; state <= S_SET_CMD; end
         S_SET_CMD   : if (!armed) begin regAddr <= 3'd0; regData <= (command == "W") ? 32'd2 : 32'd1; armed <= 1'b1; end
                       else if (tick) begin armed <= 1'b0; settle <= 4'd0; state <= S_SETTLE; end
         S_SETTLE    : begin regWrite <= 1'b0; regAddr <= 3'd3; regRead <= 1'b1;
                          if (tick) begin settle <= settle + 4'd1; if (settle == 4'd2) state <= S_POLL; end
                       end
         S_POLL      : if (tick && !busReq && !busAck && (!storageOut[0] || storageOut[1])) begin
                          regRead <= 1'b0;
                          failed  <= storageOut[1];
                          state   <= S_SEND_STATUS;
                       end
         S_SEND_STATUS : if (failed) send("E", S_COMMAND);
                         else if (command == "W") send("K", S_COMMAND);
                         else begin byteIndex <= 9'd0; sum <= 16'd0; send("K", S_SEND_DATA); end
         S_SEND_DATA : state <= S_SEND_DATA2;               // memWord follows byteIndex a clock later
         S_SEND_DATA2: begin
                          sum <= sum + {8'd0, memByte};
                          byteIndex <= byteIndex + 9'd1;
                          send(memByte, (byteIndex == 9'd511) ? S_SEND_SUM : S_SEND_DATA);
                          if (byteIndex == 9'd511) count <= 2'd0;
                       end
         S_SEND_SUM  : begin count <= count + 2'd1;
                          send(count == 2'd0 ? sum[7:0] : sum[15:8], count == 2'd0 ? S_SEND_SUM : S_COMMAND);
                       end
         S_SEND_ID   : begin count <= count + 2'd1;
                          case (count)
                             2'd0: send("S", S_SEND_ID);
                             2'd1: send("D", S_SEND_ID);
                             2'd2: send("B", S_SEND_ID);
                             2'd3: send("1", S_COMMAND);
                          endcase
                       end
         S_WAIT_SEND : if (!txStart && !txBusy) state <= afterSend;
         default     : state <= S_COMMAND;
      endcase
   end
endmodule

// 8N1 receiver: waits for a start bit, samples each bit in its middle
module uart_rx #(parameter CLKS_PER_BIT = 234) (
   input            clk,
   input            rx,
   output reg       valid = 1'b0,
   output reg [7:0] data = 8'd0
);
   reg [1:0]  sync = 2'b11;
   reg [15:0] timer = 16'd0;
   reg [3:0]  bitn = 4'd0;
   reg        busy = 1'b0;
   reg [7:0]  shift = 8'd0;
   always @(posedge clk) begin
      sync  <= {sync[0], rx};
      valid <= 1'b0;
      if (!busy) begin
         if (!sync[1]) begin busy <= 1'b1; timer <= CLKS_PER_BIT / 2; bitn <= 4'd0; end
      end else if (timer != 16'd0)
         timer <= timer - 16'd1;
      else begin
         timer <= CLKS_PER_BIT - 1;
         bitn  <= bitn + 4'd1;
         if (bitn == 4'd0) begin if (sync[1]) busy <= 1'b0; end          // a glitch, not a start bit
         else if (bitn <= 4'd8) shift <= {sync[1], shift[7:1]};
         else begin busy <= 1'b0; if (sync[1]) begin data <= shift; valid <= 1'b1; end end
      end
   end
endmodule

// 8N1 transmitter
module uart_tx #(parameter CLKS_PER_BIT = 234) (
   input       clk,
   input       start,
   input [7:0] data,
   output reg  tx = 1'b1,
   output reg  busy = 1'b0
);
   reg [15:0] timer = 16'd0;
   reg [3:0]  bitsLeft = 4'd0;      // data bits and the stop bit still to go out
   reg [8:0]  frame = 9'h1ff;
   always @(posedge clk)
      if (!busy) begin
         if (start) begin
            tx <= 1'b0;                                     // the start bit
            frame <= {1'b1, data};
            bitsLeft <= 4'd9;
            timer <= CLKS_PER_BIT - 1;
            busy <= 1'b1;
         end
      end else if (timer != 16'd0)
         timer <= timer - 16'd1;
      else if (bitsLeft == 4'd0)
         busy <= 1'b0;                                      // the stop bit has had its time
      else begin
         tx <= frame[0];
         frame <= {1'b1, frame[8:1]};
         bitsLeft <= bitsLeft - 4'd1;
         timer <= CLKS_PER_BIT - 1;
      end
endmodule
