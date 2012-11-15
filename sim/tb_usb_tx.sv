/* Testbench USB-TX */

module tb_usb_tx;
   timeunit 1ns;
   timeprecision 1ps;

   const realtime tusb=1s/1.5e6, // low speed
		  tclk=tusb/4;


   import types::*;

   bit           reset=1;
   bit           clk;
   var d_port_t  d;
   bit [7:0]     data;
   bit           valid;
   wire          ready;

   integer seed;

   usb_tx dut(.*);

   initial forever #(tclk/2) clk=~clk;

   always @(posedge clk)
     if(ready)
       data=$random;

   initial
     begin
	repeat(3) @(posedge clk);
	reset=0;

	repeat(10) @(posedge clk);
	valid=1;
	repeat(4*8*5) @(posedge clk);
	valid=0;

	repeat(30) @(posedge clk);
	#3us $stop;
     end
endmodule
