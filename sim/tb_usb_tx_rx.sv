/* Testbench USB-TX/RX 
 * RX is connected with TX.
 */

module tb_usb_tx_rx;
   timeunit 1ns;
   timeprecision 1ps;

   const realtime tusb=1s/1.5e6, // low speed
		  tclk=1s/24.0e6;

   import types::*;

   bit          reset=1'b1;
   bit          clk;

   d_port_t    d;
   d_port_t    line_state;

   logic [7:0] tx_data;
   bit         tx_valid;
   wire        tx_ready;
	       
   wire        rx_clk_en;
   d_port_t    rxd;
   wire [7:0]  rx_data;
   wire        rx_active,rx_valid,rx_error;

   cdr    cdr(.*,.q(rxd),.strobe(rx_clk_en));
   
   usb_rx usb_rx(.*,.clk_en(rx_clk_en),.data(rx_data),.active(rx_active),.valid(rx_valid),.error(rx_error));

   usb_tx usb_tx(.*,.data(tx_data),.valid(tx_valid),.ready(tx_ready));

   initial forever #(tclk/2) clk=~clk;

   always @(posedge clk)
     if(tx_ready)
       tx_data=$random;

   initial
     begin
	repeat(3) @(posedge clk);
	reset=1'b0;

	repeat(10) @(posedge clk);
	tx_valid<=1'b1; tx_data<=8'hc3;
	repeat(16*8*100) @(posedge clk);
	tx_valid=1'b0;

	repeat(16*8) @(posedge clk);
	$stop;
     end
endmodule
