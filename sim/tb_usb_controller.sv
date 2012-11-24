/* Testbench USB-Controller */

module tb_usb_controller;
   timeunit 1ns;
   timeprecision 1ps;

   const realtime tusb=1s/1.5e6, // low speed
		  tclk=1s/24.0e6;

   import types::*;

   bit          reset=1'b1;   // system reset
   bit          clk;          // system clock (24 MHz)

   /* USB Bus */
   var d_port_t line_state=J; // synchronized D+,D-

   /* TX */
   wire   [7:0] tx_data;      // data from SIE
   wire         tx_valid;     // rise:SYNC,1:send data,fall:EOP
   bit          tx_ready;     // data has been sent

   /* RX */
   bit    [7:0] rx_data;      // data to SIE
   bit          rx_active;    // active between SYNC und EOP
   bit          rx_valid;     // data valid pulse
   bit          rx_error;     // error detected

   /* Device */
   pid_t        pid;          // PID
   wire   [6:0] address;      // device address
   wire   [3:0] end_point;    // end point
   wire         token_valid;  // token valid

   usb_controller dut(.*);

   initial forever #(tclk/2) clk=~clk;

   initial
     begin:main
	repeat(3) @(posedge clk);
	reset=1'b0;

	#100ns;
	@(posedge clk) rx_active=1'b1;

	send(SETUP,7'h15,4'he,5'b11101);
	send(OUT,7'h3a,4'ha,5'b00111);
	send(IN,7'h70,4'h4,5'b01110);

	@(posedge clk) rx_active=1'b0;

	#1us $stop;
     end:main

   task send(pid_t pid,logic [6:0] addr,logic [3:0] endp,logic [4:0] crc5);
      /* PID */
      repeat(128-1) @(posedge clk);
      rx_valid<=1'b1;
      rx_data <={~pid,pid};
      @(posedge clk) rx_valid<=1'b0;

      /* ADDR and first bit of ENDP */
      repeat(128-1) @(posedge clk);
      rx_valid<=1'b1;
      rx_data <={endp[0],addr};
      @(posedge clk) rx_valid<=1'b0;

      /* Rest of ENDP and CRC5 */
      repeat(128-1) @(posedge clk);
      rx_valid<=1'b1;
      rx_data <={crc5,endp[3:1]};
      @(posedge clk) rx_valid<=1'b0;

      /* EOP */
      @(posedge clk) line_state<=SE0;
      repeat(32) @(posedge clk);
      line_state<=J;
   endtask
endmodule