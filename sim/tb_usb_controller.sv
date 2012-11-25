/* Testbench USB-Controller */

module tb_usb_controller;
   timeunit 1ns;
   timeprecision 1ps;

   const realtime tusb=1s/1.5e6, // low speed
		  tclk=1s/24.0e6;

   import types::*;

   bit          reset=1'b1;   // system reset
   bit          clk;          // system clock (24 MHz)

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
   wire         pid_valid;    // PID valid
   wire   [6:0] address;      // device address
   wire   [3:0] end_point;    // end point
   wire         token_valid;  // token valid
   wire   [7:0] data_o;       // data output
   wire         data_valid;   // data output valid
   wire         crc16_ok;     // data CRC16
   bit    [7:0] data_i;       // data input
   bit          data_ready;   // data input ready

   /* some data */
   byte data0[]='{8'h00,8'h01,8'h02,8'h03},
	data1[]='{8'h23,8'h45,8'h67,8'h89};

   usb_controller dut(.*);

   initial forever #(tclk/2) clk=~clk;

   initial
     begin:main
	repeat(3) @(posedge clk);
	reset=1'b0;

	#100ns;
	@(posedge clk) rx_active=1'b1;

	send_token(SETUP,7'h15,4'he);
	send_token(OUT,7'h3a,4'ha);
	send_token(IN,7'h70,4'h4);

	send_data(DATA0,data0);
	send_data(DATA1,data1);

	send_handshake(ACK);
	send_handshake(NAK);
	send_handshake(STALL);

	@(posedge clk) rx_active=1'b0;

	#3us $stop;
     end:main

   task send_token(pid_t pid,logic [6:0] addr,logic [3:0] endp);
      /* PID */
      repeat(128-1) @(posedge clk);
      rx_active<=1'b1;
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
      rx_data <={crc5({endp,addr}),endp[3:1]};
      @(posedge clk) rx_valid<=1'b0;

      /* EOP */
      repeat(32) @(posedge clk);
      rx_active<=1'b0;
   endtask

   task send_data(pid_t pid,byte data[]);
      /* PID */
      repeat(128-1) @(posedge clk);
      rx_active<=1'b1;
      rx_valid<=1'b1;
      rx_data <={~pid,pid};
      @(posedge clk) rx_valid<=1'b0;

      foreach(data[i])
	begin
	   repeat(128-1) @(posedge clk);
	   rx_valid<=1'b1;
	   rx_data <=data[i];
	   @(posedge clk) rx_valid<=1'b0;
	end

      /* CRC16 */
      // TODO

      /* EOP */
      repeat(32) @(posedge clk);
      rx_active<=1'b0;
   endtask

   task send_handshake(pid_t pid);
      /* PID */
      repeat(128-1) @(posedge clk);
      rx_active<=1'b1;
      rx_valid<=1'b1;
      rx_data <={~pid,pid};
      @(posedge clk) rx_valid<=1'b0;

      /* EOP */
      repeat(32) @(posedge clk);
      rx_active<=1'b0;
   endtask

   function [4:0] crc5(input [10:0] d);
      const bit [4:0] crc5_poly=5'b10100,
		      crc5_res =5'b00110;

      crc5='1;

      for(int i=$right(d);i<=$left(d);i++)
	if(crc5[$right(crc5)]^d[i])
	  crc5=(crc5>>1)^crc5_poly;
	else
	  crc5=crc5>>1;

      crc5=~crc5;
   endfunction
endmodule