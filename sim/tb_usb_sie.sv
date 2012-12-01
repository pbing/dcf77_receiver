/* Testbench USB Serial Interface Controller */

module tb_usb_sie;
   timeunit 1ns;
   timeprecision 1ps;

   const realtime tusb=1s/1.5e6,       // low speed
		  tclk=1s/24.0e6;

   localparam num_endp=3;              // number of endpoints (1...3 for low-speed devices)

   import types::*;

   bit          reset=1'b1;            // system reset
   bit          clk;                   // system clock (24 MHz)

   /* Transceiver */
   wire   [7:0] tx_data;               // data from SIE
   wire         tx_valid;              // rise:SYNC,1:send data,fall:EOP
   bit          tx_ready=1'b1;         // data has been sent

   bit    [7:0] rx_data;               // data to SIE
   bit          rx_active;             // active between SYNC und EOP
   bit          rx_valid;              // data valid pulse
   bit          rx_error;              // error detected

   /* Device */
   bit    [6:0] device_addr=42;           // assigned device address

   logic  [7:0] endpi_data[num_endp];  // IN endpoint data input
   logic        endpi_valid[num_endp]; // IN endpoint data valid
   logic        endpi_crc16[num_endp]; // IN endpoint calculate CRC16
   wire         endpi_ready[num_endp]; // IN endpoint data ready

   wire   [7:0] endpo_data[num_endp];  // OUT endpoint data output
   wire         endpo_valid[num_endp]; // OUT endpoint data valid
   wire         endpo_crc16[num_endp]; // OUT endpoint CRC16 flag
   logic        endpo_ready[num_endp]; // OUT endpoint data ready

   /* some data */
   byte data0[]='{8'h00,8'h01,8'h02,8'h03}, // CRC16=8'hef,8'h7a
	data1[]='{8'h23,8'h45,8'h67,8'h89}; // CRC16=8'h0e,8'h1c

   usb_sie #(num_endp) dut(.*);

   initial forever #(tclk/2) clk=~clk;

   initial
     begin:main
	repeat(3) @(posedge clk);
	reset=1'b0;

	#100ns;

	//send_token(SETUP,7'h15,4'he); // invalid control endpoint
	send_token(SETUP,device_addr,4'h0);
	send_data(DATA0,data0);

	//send_token(OUT,7'h3a,4'ha);
	send_token(OUT,device_addr,4'h1);
	send_data(DATA0,data0);
	send_token(OUT,device_addr,4'h1);
	send_data(DATA1,data1);

//	send_token(IN,7'h70,4'h4);
//	send_token(IN,device_addr,4'h2);

/* -----\/----- EXCLUDED -----\/-----
	send_handshake(ACK);
	send_handshake(NAK);
	send_handshake(STALL);
 -----/\----- EXCLUDED -----/\----- */

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

   task send_data(input pid_t pid,input byte data[]);
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
      for(int i=0;i<16;i+=8)
	begin
	   repeat(128-1) @(posedge clk);
	   rx_valid<=1'b1;
	   rx_data <=crc16(data)[7+i-:8];
	   @(posedge clk) rx_valid<=1'b0;
	end


      /* EOP */
      repeat(32) @(posedge clk);
      rx_active<=1'b0;
   endtask

   task send_handshake(input pid_t pid);
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

   function [15:0] crc16(input byte d[]);
      const bit [15:0] crc16_poly=16'b1010000000000001,
		       crc16_res =16'b1011000000000001;

      crc16='1;

      foreach(d[j])
	for(int i=$right(d[j]);i<=$left(d[j]);i++)
	  if(crc16[$right(crc16)]^d[j][i])
	    crc16=(crc16>>1)^crc16_poly;
	  else
	    crc16=crc16>>1;

      crc16=~crc16;
   endfunction
endmodule
