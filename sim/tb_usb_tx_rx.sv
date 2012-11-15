/* Testbench USB-TX/RX */

module tb_usb_tx_rx;
   timeunit 1ns;
   timeprecision 1ps;

   const realtime tusb=1s/1.5e6, // low speed
		  tclk=tusb/4;
   

   import types::*;

   bit           reset=1;
   bit           clk;
   wire d_port_t d;

   logic [7:0]   tx_data;
   bit           tx_valid;
   wire          tx_ready;

   wire [7:0]    rx_data;
   wire          rx_active,rx_valid,rx_error;
   wire d_port_t rx_line_state;
   
   /* packets */
   typedef enum bit [3:0] {/* Token */
			   OUT=4'b001,
			   IN=4'b1001,
			   SOF=4'b0101,
			   SETUP=4'b1101,
			   /* Data */
			   DATA0=4'b0011,
			   DATA1=4'b1011,
			   /* Handshake */
			   ACK=4'b0010,
			   NACK=4'b1010,
			   STALL=4'b1110,
			   /* SPECIAL */
			   PRE_ERR=4'b1100
			   } pid_t;

   usb_tx usb_tx(.*,.data(tx_data),.valid(tx_valid),.ready(tx_ready));
   
   usb_rx usb_rx(.*,.data(rx_data),.active(rx_active),.valid(rx_valid),.error(rx_error),.line_state(rx_line_state));

   initial forever #(tclk/2) clk=~clk;

   initial
     begin
	repeat(3) @(posedge clk);
	reset=0;

	#1us;
	tx_data=8'h01; tx_valid=1;

	do @(posedge clk); while(!tx_ready);
	tx_data='z;
	tx_valid=0;
	
	repeat(100) @(posedge clk);
	#100ns $stop;
     end
endmodule
