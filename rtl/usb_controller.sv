/* USB controller */

module usb_controller
  import types::*;
   (input              reset,      // system reset
    input              clk,        // system clock (24 MHz)

    /* USB Bus */
    input     d_port_t line_state, // synchronized D+,D-

    /* TX */
    output       [7:0] tx_data,    // data from SIE
    output             tx_valid,   // rise:SYNC,1:send data,fall:EOP
    input              tx_ready,   // data has been sent

    /* RX */
    input        [7:0] rx_data,    // data to SIE
    input              rx_active,  // active between SYNC und EOP
    input              rx_valid,   // data valid pulse
    input              rx_error,   // error detected

    /* Device */
    output logic [6:0] address,    // device address
    output logic [3:0] end_point); // end point

   enum logic [31:0] {IDLE,TOKEN[3]} state;

   /* FIXME */
   assign tx_data =8'h0;
   assign tx_valid=1'b0;

   (* noprune *) var   pid_t pid;
   (* noprune *) logic [4:0] crc5;

   always_ff @(posedge clk)
     if(reset)
       begin
	  state    <=IDLE;
	  pid      <=pid_t'('0);
	  address  <=7'b0;
	  end_point<=4'b0;
	  crc5     <=5'b0;
       end
     else
       case(state)
	 IDLE:
	   if(rx_valid && !rx_error)
	     if(valid_pid(rx_data))
	       begin
		  var pid_t current_pid;

		  current_pid=pid_t'(rx_data[3:0]);
		  pid       <=current_pid;

		  case(current_pid)
		    OUT,IN,SETUP: state<=TOKEN0;
		  endcase
	       end
	     else
	       pid<=pid_t'('0);

	 TOKEN0:
	   if(rx_valid)
	     if(!rx_error)
	       begin
		  address     <=rx_data[6:0];
		  end_point[0]<=rx_data[7];
		  state       <=TOKEN1;
	       end
	     else
	       state<=IDLE;

	 TOKEN1:
	   if(rx_valid)
	     if(!rx_error)
	       begin
		  end_point[3:1]<=rx_data[2:0];
		  crc5          <=rx_data[7:3];

		  if(valid_crc5({rx_data,end_point[3],address}))
		    state<=TOKEN2; // FIXME
		  else
		    state<=IDLE;
	       end
	     else
	       state<=IDLE;
       endcase

   /************************************************************************
    * Functions
    ************************************************************************/

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
      const bit [4:0] crc5_poly=5'b10100, // inverse direction
		      crc5_res =5'b00110; // inverse direction
      logic [4:0] crc5;

      crc5='1;

      for(int i=$right(d);i<=$left(d);i++)
	if(crc5[$right(crc5)]^d[i])
	  crc5=(crc5>>1)^crc5_poly;
	else
	  crc5=crc5>>1;

      valid_crc5=(crc5_res == crc5);
   endfunction
endmodule
