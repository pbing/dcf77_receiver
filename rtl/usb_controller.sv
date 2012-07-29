/* USB controller */

module usb_controller(input                       reset,       // system reset
		      input                       clk,         // system clock (24 MHz)
	      	      input [7:0]                 data,        // data to SIE
		      input	                  active,      // active between SYNC und EOP
	      	      input                       valid,       // data valid pulse
		      input 	                  error,       // error detected
		      input 	  types::d_port_t line_state); // synchronized D+,D-

   typedef enum logic [3:0] {RESERVED,OUT,ACK,DATA0,
			     PING,SOF,NYET,DATA2,
			     SPLIT,IN,NACK,DATA1,
			     PRE,SETUP,STALL,MDATA} pid_t;

   enum logic [31:0] {IDLE,TOKEN[3]} state,next;

   (* noprune *) pid_t       pid;
   (* noprune *) logic [6:0] address;
   (* noprune *) logic [3:0] end_point;
   (* noprune *) logic       flag_crc5;
   
   always_ff @(posedge clk)
     if(reset)
       begin
	  pid<=RESERVED;
	  address<='0;
	  end_point<='0;
	  flag_crc5<='0;
       end
     else if(valid)
       begin
	  if(valid_pid(data))
	    pid<=pid_t'(data[3:0]);

	  if(pid==IN)
	    begin
	       address<=data[6:0];
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
