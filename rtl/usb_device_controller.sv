/* USB device controller 
 * Endpoint address is always 0.
 */

module usb_device_controller(if_wishbone.slave wb);

   logic [7:0] data;

   /* DEBUG */
   always_ff @(posedge wb.clk)
     if(wb.rst)
       data<=8'h00;
     else
       if(wb.addr==4'd0 && wb.we)
	 data<=wb.data_m;

   /* synchronous slave */
   always_ff @(posedge wb.clk)
     if(wb.rst)
       wb.ack<=1'b0;
     else
       if(wb.ack)
	 wb.ack<=1'b0;
       else if(wb.cyc && wb.stb)
	 wb.ack<=1'b1;
endmodule
