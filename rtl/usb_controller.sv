/* USB controller */

module usb_controller
  import types::*;
   (input          reset,      // system reset
    input          clk,        // system clock (24 MHz)

    /* USB Bus */
    input d_port_t line_state, // synchronized D+,D-

    /* TX */
    output [7:0]   tx_data,    // data from SIE
    output         tx_valid,   // rise:SYNC,1:send data,fall:EOP
    input          tx_ready,   // data has been sent

    /* RX */
    input  [7:0]   rx_data,    // data to SIE
    input          rx_active,  // active between SYNC und EOP
    input          rx_valid,   // data valid pulse
    input          rx_error);  // error detected

   enum logic [31:0] {IDLE,TOKEN[3]} state,next;

   /* FIXME */
   assign tx_data =8'h0;
   assign tx_valid=1'b0;

   (* noprune *) var   pid_t pid;
   (* noprune *) logic [6:0] address;
   (* noprune *) logic [3:0] end_point;
   (* noprune *) logic       flag_crc5;

   always_ff @(posedge clk)
     if(reset)
       begin
	  address  <='0;
	  end_point<='0;
	  flag_crc5<='0;
       end
     else if(rx_valid)
       begin
	  if(valid_pid(rx_data))
	    pid<=pid_t'(rx_data[3:0]);

	  if(pid==IN)
	    begin
	       address<=rx_data[6:0];
	    end
       end


   function valid_pid(input [7:0] d);
      valid_pid=(d[3:0] == ~d[7:4]);
   endfunction

   /*
    * CRC5 = x^5 + x^2 + 1
    *
    * If all token bits are received without error the residual will
    * be 5'b01100.
    */
   function valid_crc5(input [15:0] d);
      const bit [4:0] crc5_poly=5'b00101,
		      crc5_res =5'b01100;
      logic [4:0] crc5;

      crc5='1;

      for(int i=$low(d);i<=$high(d);i++)
	if(crc5[$left(crc5)]^d[i])
	  crc5=(crc5<<1)^crc5_poly;
	else
	  crc5=crc5<<1;

      valid_crc5=(crc5_res == ~crc5);
   endfunction
endmodule
