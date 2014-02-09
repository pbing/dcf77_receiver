/* USB Serial Interface Controller */

module usb_sie (if_wishbone.master wb,           // Device interface
		if_transceiver     transceiver); // USB tranceiver interface

   import types::*;

   var token_t token;

   logic [6:0]  device_addr;  // FIXME assigned device address
   logic        packet_ready; // FIXME fsm_packet_state != S_TOKEN0 && transceiver.eop?
   logic [15:0] crc16;        // CRC16
   logic [7:0]  data[3];      // needed in order to strip CRC16

   /* FIXME */
   always_comb
     begin
	transceiver.tx_data =8'd42;
	transceiver.tx_valid=1'b0;
     end

   /************************************************************************
    * Packet FSM
    ************************************************************************/
   enum int unsigned {S_TOKEN[3],S_DATA[3]} fsm_packet_state,fsm_packet_next;

   always_ff @(posedge wb.clk)
     if(wb.rst)
       fsm_packet_state<=S_TOKEN0;
     else
       fsm_packet_state<=fsm_packet_next;

   always_comb
     if(!transceiver.rx_active)
       fsm_packet_next=S_TOKEN0;
     else
       begin
	  fsm_packet_next=fsm_packet_state;

	  if(transceiver.rx_valid)
	    case(fsm_packet_state)
	      S_TOKEN0:
		begin
		   var pid_t pid;
		   pid=pid_t'(transceiver.rx_data[3:0]);

		   case(pid)
		     OUT,IN,SETUP:
		       fsm_packet_next=S_TOKEN1;

		     DATA0,DATA1:
		       fsm_packet_next=S_DATA0;

		     default
		       fsm_packet_next=S_TOKEN0;
		   endcase
		end

	      S_TOKEN1: fsm_packet_next=S_TOKEN2;

	      S_TOKEN2: fsm_packet_next=S_TOKEN0;

	      S_DATA0: fsm_packet_next=S_DATA1;

	      S_DATA1: fsm_packet_next=S_DATA2;

	      S_DATA2: ;
	    endcase
       end

   /************************************************************************
    * Save host data
    ************************************************************************/

   always_ff @(posedge wb.clk)
     if(!transceiver.rx_active)
       begin
	  token.pidx<=4'b0;
	  token.pid <=RESERVED;
	  token.addr<=7'd0;
	  token.endp<=4'd0;
	  token.crc5<=5'h0;

	  crc16     <=16'hffff;
       end
     else
       if(transceiver.rx_valid)
	 case(fsm_packet_state)
	   /* Save values during TOKEN stage. */
	   S_TOKEN0:
	     begin
		token.pidx<=transceiver.rx_data[7:4];
		token.pid <=pid_t'(transceiver.rx_data[3:0]);
	     end

	   S_TOKEN1:
	     begin
		token.addr   <=transceiver.rx_data[6:0];
		token.endp[0]<=transceiver.rx_data[7];
	     end

	   S_TOKEN2:
	     begin
		token.endp[3:1]<=transceiver.rx_data[2:0];
		token.crc5     <=transceiver.rx_data[7:3];
	     end

	   /* Calculate CRC16 during DATA stage. */
	   S_DATA0,S_DATA1,S_DATA2:
	     crc16 <=step_crc16(transceiver.rx_data);
	 endcase

   always_ff @(posedge wb.clk)
     if(wb.rst)
       begin
	  data[0]<=8'h00;
	  data[1]<=8'h00;
	  data[2]<=8'h00;

	  wb.cyc<=1'b0;
	  wb.stb<=1'b0;
	  wb.we <=1'b0;
       end
     else
       if(wb.ack)
	 begin
	    wb.cyc<=1'b0;
	    wb.stb<=1'b0;
	    wb.we <=1'b0;
	 end
       else if(transceiver.rx_valid)
	 case(fsm_packet_state)
	   S_DATA0,S_DATA1:
	     begin
		data[0]<=transceiver.rx_data;
		data[1]<=data[0];
		data[2]<=data[1];
	     end

	   S_DATA2:
	     begin
		data[0]<=transceiver.rx_data;
		data[1]<=data[0];
		data[2]<=data[1];

		wb.cyc<=1'b1;
		wb.stb<=1'b1;
		wb.we <=1'b1;
	     end
	 endcase

   always_comb
     begin
	wb.addr  =token.endp;
	wb.data_m=data[2];    // Delay wb.data_m by two cycles in order to strip CRC16.
     end



   /************************************************************************
    * validy checks
    ************************************************************************/
   /* DEBUG */
   wire dbg_valid_token = valid_token(token);
   wire dbg_valid_data  = valid_crc16(crc16);



   /************************************************************************
    * Functions
    ************************************************************************/

   function valid_token(input token_t token);
      valid_token=(token.pid == ~token.pidx) && valid_crc5({token.crc5,token.endp,token.addr});
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

   function valid_crc16(input [15:0] crc16);
      const bit [15:0] crc16_res =16'b1011000000000001;

      valid_crc16=(crc16_res == crc16);
   endfunction
endmodule
