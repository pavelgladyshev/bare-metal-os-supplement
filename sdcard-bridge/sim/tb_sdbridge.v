// Simulation of sdbridge with the card model: ping, read, write, read back, a bad sum, an unfinished request,
// and no card. The serial port runs fast (CLKS_PER_BIT 8) so that the simulation is short.
`timescale 1ns/1ps
module tb_sdbridge;
   reg clk = 0; always #18.5 clk = ~clk;                   // about 27 MHz
   localparam CPB = 8;
   reg  hostTx = 1'b1;
   wire boardTx, sck, mosi, cs, miso;
   wire [5:0] led;
   sdbridge #(.CLOCK_HZ(27000000), .BAUD(27000000/CPB)) DUT (
      .clk(clk), .uart_rx(hostTx), .uart_tx(boardTx), .sd_sck(sck), .sd_mosi(mosi), .sd_cs(cs), .sd_miso(miso), .led(led));
   sd_card_model #(.HIGH_CAPACITY(`HC), .PRESENT(`PRESENT), .BLOCKS(16)) CARD (.sck(sck), .mosi(mosi), .cs(cs), .miso(miso));

   task sendByte(input [7:0] b); integer i; begin
      hostTx = 0; repeat (CPB) @(posedge clk);
      for (i = 0; i < 8; i = i + 1) begin hostTx = b[i]; repeat (CPB) @(posedge clk); end
      hostTx = 1; repeat (CPB) @(posedge clk);
   end endtask
   task getByte(output [7:0] b); integer i; begin
      @(negedge boardTx); repeat (CPB/2) @(posedge clk);
      for (i = 0; i < 8; i = i + 1) begin repeat (CPB) @(posedge clk); b[i] = boardTx; end
      repeat (CPB) @(posedge clk);
   end endtask
   task send32(input [31:0] v); begin sendByte(v[7:0]); sendByte(v[15:8]); sendByte(v[23:16]); sendByte(v[31:24]); end endtask

   reg [7:0] b, st; reg [7:0] data [0:511]; reg [15:0] s, sIn; integer i, errors = 0;
   task readBlock(input [31:0] n, output [7:0] status); begin
      sendByte("R"); send32(n); getByte(status);
      if (status == "K") begin
         s = 0; for (i = 0; i < 512; i = i + 1) begin getByte(data[i]); s = s + data[i]; end
         getByte(sIn[7:0]); getByte(sIn[15:8]);
         if (sIn != s) begin $display("FAIL read %0d: sum %h, expected %h", n, sIn, s); errors = errors + 1; end
      end
   end endtask
   task writeBlock(input [31:0] n, input [7:0] seed, input corrupt, output [7:0] status); begin
      sendByte("W"); send32(n); s = 0;
      for (i = 0; i < 512; i = i + 1) begin sendByte((i * 3 + seed) & 8'hff); s = s + ((i * 3 + seed) & 8'hff); end
      if (corrupt) s = s + 1;
      sendByte(s[7:0]); sendByte(s[15:8]); getByte(status);
   end endtask

   initial begin
      #200000;                                               // the card's power-up wait
      sendByte("P"); getByte(b); $write("%c", b); getByte(b); $write("%c", b); getByte(b); $write("%c", b); getByte(b); $display("%c", b);
      if (`PRESENT) begin
         readBlock(3, st); $display("read 3: %c, first bytes %h %h, card has %h %h", st, data[0], data[1], CARD.mem[3*512], CARD.mem[3*512+1]);
         if (st != "K" || data[0] != CARD.mem[3*512] || data[511] != CARD.mem[3*512+511]) errors = errors + 1;
         writeBlock(5, 8'd17, 0, st); $display("write 5: %c, card now %h %h %h", st, CARD.mem[`HC ? 5*512 : 5*512], CARD.mem[5*512+1], CARD.mem[5*512+511]);
         if (st != "K" || CARD.mem[5*512] != 8'd17 || CARD.mem[5*512+511] != ((511*3+17) & 8'hff)) errors = errors + 1;
         readBlock(5, st); if (st != "K" || data[100] != ((300+17) & 8'hff)) begin errors = errors + 1; $display("FAIL read-back"); end
         else $display("read back 5: %c, byte 100 = %h", st, data[100]);
         writeBlock(6, 8'd99, 1, st); $display("write 6 with a bad sum: %c, card block 6 byte 0 still %h", st, CARD.mem[6*512]);
         if (st != "C") errors = errors + 1;
         sendByte("R"); sendByte(8'd1);                        // an unfinished request ...
         #(600*1000*1000);                                     // ... abandoned after half a second
         sendByte("P"); getByte(b); $display("after an unfinished request, ping answers %c", b);
         if (b != "S") errors = errors + 1; getByte(b); getByte(b); getByte(b);
      end else begin
         readBlock(0, st); $display("no card, read: %c", st); if (st != "E") errors = errors + 1;
      end
      if (errors) $display("FAILED, %0d errors", errors); else $display("PASSED");
      $finish;
   end
endmodule
