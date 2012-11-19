/* USB Transceiver */

module usb_transceiver
  import types::*;
   (input        reset,      // reset
    input        clk,        // system clock (24 MHz)

    /* USB Bus */
    d_port_t     d_i,        // USB port D+,D- (input)
    d_port_t     d_o,        // USB port D+,D- (output)
    logic        d_en;       // USB port D+,D- (enable)
    d_port_t     line_state, // synchronized D+,D-

    /* TX */
    input  [7:0] tx_data,    // data from SIE
    input        tx_valid,   // rise:SYNC,1:send data,fall:EOP
    output       tx_ready,   // data has been sent

    /* RX */
    output [7:0] rx_data,    // data to SIE
    output       rx_active,  // active between SYNC und EOP
    output       rx_valid,   // data valid pulse
    output       rx_error);  // error detected

   wire     rx_clk_en;       // RX clock enable
   d_port_t rx_d_i;          // RX data from CDR

   cdr cdr(.reset(reset),.clk(clk),
	   .d(d_i),.q(rx_d_i),
 	   .line_state(line_state),.strobe(rx_clk_en));

   usb_rx usb_rx(.reset(reset),.clk(clk),.clk_en(rx_clk_en),
		 .d_i(rx_d_i),
		 .data(rx_data),.active(rx_active),
		 .valid(rx_valid),.error(rx_error));

   usb_tx usb_tx(.reset(reset),.clk(clk),
		 .d_o(d_o),.d_en(d_en),
		 .data(tx_data),.valid(tx_valid),.ready(tx_ready));
endmodule
