/* USB Serial Interface Controller */

module usb_sie #(parameter 
		 num_endpi=1, // number of in endpoints (1...3 for low-speed devices)
		 num_endpo=1) // number of out endpoints (1...3 for low-speed devices)
   (input              reset,                  // system reset
    input              clk,                    // system clock (24 MHz)

    if_transceiver     transceiver,

    /* Device */
    input        [6:0] device_addr,            // assigned device address

    if_endpoint        endpi,
    if_endpoint        endpo);

   import types::*;

   /* TOKEN stage */
   struct {
      pid_t       pid;  // PID
      logic [6:0] addr; // address
      logic [3:0] endp; // endpoint
      logic [4:0] crc5; // CRC5
   } token;

   /* DATA stage */
   var   pid_t  pid2;   // PID
   logic [15:0] crc16;  // CRC16

   enum int unsigned {IDLE,DO_TOKEN[3],DO_BCINTO[4],DO_BCINTI[100]} state; // FSM states

   always_ff @(posedge clk)
     if(reset)
       begin
	  for(int i=0;i<num_endpi;i++)
	       endpi.ready[i]<=1'b0;
	  for(int i=0;i<num_endpo;i++)
	    begin
	       endpo.data[i] <=8'h0;
	       endpo.valid[i]<=1'b0;
	    end
	  transceiver.tx_data   <=8'h0;
	  transceiver.tx_valid  <=1'b0;
	  token.pid <=RESERVED;
	  token.addr<=7'd0;
	  token.endp<=4'd0;
	  token.crc5<=5'h1f;
	  pid2      <=RESERVED;
	  crc16     <=16'hffff;
	  state     <=IDLE;
       end
     else
       begin
	  transceiver.tx_valid<=1'b0;
	  for(int i=0;i<num_endpo;i++)
	    begin
	       endpo.valid[i]<=1'b0;
	    end

	  case(state)
	    IDLE:
	      begin
		 crc16<=16'hffff;

		 if(transceiver.rx_valid && valid_pid(transceiver.rx_data))
		   begin
		      token.pid<=pid_t'(transceiver.rx_data[3:0]);
		      state    <=DO_TOKEN0;
		   end
	      end

	    DO_TOKEN0:
	      if(transceiver.rx_valid)
		begin
		   {token.endp[0],token.addr}<=transceiver.rx_data;
		   state<=DO_TOKEN1;
		end

	    DO_TOKEN1:
	      if(transceiver.rx_valid)
		begin
		   {token.crc5,token.endp[3:1]}<=transceiver.rx_data;
		   state<=DO_TOKEN2;
		end

	    DO_TOKEN2:
	      begin
		 state<=IDLE;

		 if(valid_crc5({token.crc5,token.endp,token.addr}))
		   case(token.pid)
		     SETUP: if( token.endp==4'd0) state<=DO_BCINTO0;
		     OUT  : state<=DO_BCINTO0;
		     IN   : state<=DO_BCINTI0;
		   endcase
	      end

	    DO_BCINTO0:
	      if(transceiver.rx_valid)
		begin
		   state<=IDLE;

		   if(valid_pid(transceiver.rx_data))
		     begin
			pid2 <=pid_t'(transceiver.rx_data[3:0]);
			state<=DO_BCINTO1;
		     end
		end

	    DO_BCINTO1:
	      begin
		 state<=IDLE;

		 case(token.pid)
		   SETUP: if(pid2==DATA0)                state<=DO_BCINTO2;
		   OUT  : if(pid2==DATA0 || pid2==DATA1) state<=DO_BCINTO2;
		 endcase
	      end

	    DO_BCINTO2:
	      if(transceiver.rx_active)
		begin
		   if(transceiver.rx_valid)
		     begin
			endpo.data[token.endp] <=transceiver.rx_data;
			endpo.valid[token.endp]<=1'b1;
			crc16                  <=step_crc16(transceiver.rx_data);
		     end
		end
	      else
		state<=DO_BCINTO3;

	    DO_BCINTO3:
	      begin
		 transceiver.tx_data <=tx_pid(ACK);
		 transceiver.tx_valid<=1'b1;

		 if(transceiver.tx_ready)
		   state<=IDLE;
	      end

	    DO_BCINTI0: ;
	  endcase
       end

   always_comb
     for(int i=0;i<num_endpo;i++)
       if(i==token.endp)
	 endpo.crc16[i]=valid_crc16();
       else
	 endpo.crc16[i]=1'b0;

   /************************************************************************
    * Functions
    ************************************************************************/

   function valid_pid(input [7:0] d);
      valid_pid=(d[3:0] == ~d[7:4]);
   endfunction

   function [7:0] tx_pid(input pid_t p);
      tx_pid={~p,p};
   endfunction

   /*
    * CRC5 = x^5 + x^2 + 1
    *
    * If all token bits are received without error the residual will
    * be 5'b01100.
    *
    * Note, that the LSB is sent first hence the polynom and the
    * residual are reversed.
    */
   function valid_crc5(input [15:0] d);
      const bit [4:0] crc5_poly=5'b10100,
		      crc5_res =5'b00110;
      logic [4:0] crc5;

      crc5='1;

      for(int i=$right(d);i<=$left(d);i++)
	if(crc5[$right(crc5)]^d[i])
	  crc5=(crc5>>1)^crc5_poly;
	else
	  crc5=crc5>>1;

      valid_crc5=(crc5_res == crc5);
   endfunction

   /*
    * CRC16 = x^16 + x^15 + x^2 + 1
    *
    * If all token bits are received without error the residual will
    * be 16'b1000000000001101.
    *
    * Note, that the LSB is sent first hence the polynom and the
    * residual are reversed.
    */
   function [15:0] step_crc16(input [7:0] d);
      const bit [15:0] crc16_poly=16'b1010000000000001;

      step_crc16=crc16;

      for(int i=$right(d);i<=$left(d);i++)
	if(step_crc16[$right(step_crc16)]^d[i])
	  step_crc16=(step_crc16>>1)^crc16_poly;
	else
	  step_crc16=step_crc16>>1;
   endfunction

   function valid_crc16();
      const bit [15:0] crc16_res =16'b1011000000000001;

      valid_crc16=(crc16_res == crc16);
   endfunction
endmodule
