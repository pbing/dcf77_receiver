/* USB device controller */

module usb_device_controller
  import types::*;
   (input           reset, // reset
    input           clk,   // system clock (24 MHz)
    input  d_port_t d_i,   // USB port D+,D- (input)
    output d_port_t d_o,   // USB port D+,D- (output)
    output          d_en,  // USB port D+,D- (enable)
    if_io           io);   // I/O interface to J1 processor

   if_transceiver transceiver();
   if_fifo        endpi0(.clock(clk));
   if_fifo        endpo0(.clock(clk));
   if_fifo        endpi1(.clock(clk));

   usb_transceiver usb_transceiver(.reset(reset),
				   .clk(clk),
				   .d_i(d_i),
				   .d_o(d_o),
				   .d_en(d_en),
				   .transceiver(transceiver));

   usb_sie usb_sie(.clk(clk),
		   .transceiver(transceiver),
		   .endpi0(endpi0),
		   .endpo0(endpo0),
		   .endpi1(endpi1));

   fifo8x16 fifo_endpi0(.clock(endpi0.clock),
			.data(endpi0.data),
			.rdreq(endpi0.rdreq),
			.sclr(endpi0.sclr),
			.wrreq(endpi0.wrreq),
			.empty(endpi0.empty),
			.full(endpi0.full),
			.q(endpi0.q),
			.usedw(endpi0.usedw));

   fifo8x16 fifo_endpo0(.clock(endpo0.clock),
			.data(endpo0.data),
			.rdreq(endpo0.rdreq),
			.sclr(endpo0.sclr),
			.wrreq(endpo0.wrreq),
			.empty(endpo0.empty),
			.full(endpo0.full),
			.q(endpo0.q),
			.usedw(endpo0.usedw));

   fifo8x16 fifo_endpi1(.clock(endpi1.clock),
			.data(endpi1.data),
			.rdreq(endpi1.rdreq),
			.sclr(endpi1.sclr),
			.wrreq(endpi1.wrreq),
			.empty(endpi1.empty),
			.full(endpi1.full),
			.q(endpi1.q),
			.usedw(endpi1.usedw));

   io_interface io_interface(.reset(reset),
			     .clk(clk),
			     .io(io),
			     .endpi0(endpi0),
			     .endpo0(endpo0),
			     .endpi1(endpi1));
endmodule
