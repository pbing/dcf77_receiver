/* USB-2.0 low/full speed sender */

module usb_tx(input        reset, // reset from SIE
	      input 	   clk, // system clock (low speed: 6 MHz, full speed: 48 MHz)
	      output 	   types::d_port_t d, // USB port D+,D-
	      input [7:0]  data, // data from SIE
	      input 	   valid, // rise:SYNC,1:send data,fall:EOP
	      output logic ready); // data has been send

   import types::*;

   /* bit/byte clock */
   logic [2:0] num_ones;
   logic [1:0] bit_counter; // bit time=4 clocks
   logic [2:0] byte_counter;

   always_ff @(posedge clk)
     if(reset || !valid)
       begin
	  bit_counter<='0;
	  byte_counter<='0;
       end
     else
       begin
	  bit_counter<=bit_counter+2'd1;
	  if(bit_counter=='1 && num_ones!=6)
	    byte_counter<=byte_counter+3'd1;
       end

   logic en_bit,en_byte;
   
   always_comb
     begin
        en_bit=(bit_counter=='1);
	en_byte=(byte_counter=='1 && en_bit);
     end

   /*************************************************************
    * TX FSM
    *
    * Use dummy states to get a state number of powers of two.
    * Otherwise the synthesis software of Quartus will insert a
    * modulo-N divider because of tx_state.next().
    *************************************************************/
   enum logic [4:0] {RESET,TX_WAIT,SEND_SYNC[8],TX_DATA_LOAD,TX_DATA_WAIT[8],SEND_EOP[11],DUMMY[2]} tx_state,tx_next;
   logic idle,eop;
   
   always_ff @(posedge clk)
     if(reset)
       tx_state<=RESET;
     else
       tx_state<=tx_next;

   always_comb
     begin
	ready=1'b0;
	idle=1'b0;
	eop=1'b0;
	tx_next=tx_state;

	case(tx_state)
	  RESET:
	    begin
	       idle=1'b1;
	       if(!reset) tx_next=TX_WAIT;
	    end
	  
	  TX_WAIT:
	    begin
	       idle=1'b1;
	       if(valid) tx_next=SEND_SYNC0;
	    end
	  
	  SEND_SYNC0,SEND_SYNC1,SEND_SYNC2,SEND_SYNC3,
	    SEND_SYNC4,SEND_SYNC5,SEND_SYNC6,SEND_SYNC7:
	      if(en_bit) tx_next=tx_state.next();

	  TX_DATA_LOAD:
	    begin
	       ready=1'b1;
	       if(!valid)
		 begin
		    eop=1'b1;
		    tx_next=SEND_EOP0;
		 end
	       else
		 tx_next=TX_DATA_WAIT0;
	    end

	  TX_DATA_WAIT0,TX_DATA_WAIT1,TX_DATA_WAIT2,TX_DATA_WAIT3,
	    TX_DATA_WAIT4,TX_DATA_WAIT5,TX_DATA_WAIT6:
	      if(en_bit) tx_next=tx_state.next();

	  TX_DATA_WAIT7:
	     if(en_bit) tx_next=TX_DATA_LOAD;

	  SEND_EOP0,SEND_EOP1,SEND_EOP2,SEND_EOP3,
	    SEND_EOP4,SEND_EOP5,SEND_EOP6:
	    begin
	       ready=1'b0;
	       eop=1'b1;
	       tx_next=tx_state.next();
	    end
	       
	  SEND_EOP7,SEND_EOP8,SEND_EOP9:
//	  SEND_EOP[7:9]:
	    begin
	       ready=1'b0;
	       idle=1'b1;
	       eop=1'b0;
	       tx_next=tx_state.next();
	    end

	  SEND_EOP10:
	    begin
	       ready=1'b0;
	       idle=1'b1;
	       eop=1'b0;
	       tx_next=TX_WAIT;
	    end

	  default tx_next=RESET;
	endcase
     end

   /* TX load/shift register */
   logic [7:0] tx_load,tx_shift;
   logic       tx_bit;

   always_ff @(posedge clk)
     if(reset)
       tx_load<='0;
     else if(ready)
       tx_load<=data;

   always_ff @(posedge clk)
     if(reset)
       tx_shift<='0;
     else
       if(tx_state==TX_WAIT)
	 tx_shift<=8'h80; // SYNC pattern
       else if(en_byte) // FIXME
	 tx_shift<=tx_load;
       else if(tx_bit)
	 tx_shift<={1'bx,tx_shift[7-:7]};


   /* bit stuffing */
   logic tx_serial;
   
   always_ff @(posedge clk) // FIXME
     if(reset)
       num_ones<='0;
     else if(en_bit)
       if(tx_shift[0])
	 if(num_ones=='d6)
	   begin
	      num_ones<='0;
	   end
	 else
	   begin
	      num_ones<=num_ones+3'd1;
	   end

   always_comb tx_bit=(en_bit && num_ones!='d6);
   always_comb tx_serial=(num_ones!='d6)?tx_shift[0]:1'b0;

   /* NRZI coding */
   logic nrzi;

   always_ff @(posedge clk)
     if(reset)
       nrzi<=1'b0;
     else if(en_bit)
       nrzi<=tx_serial^~nrzi;

   /* assign D+,D- */
   always_comb
     if(eop)
       d=SE0;
     else if(idle)
       d=J;
     else
       d=(nrzi)?K:J;
endmodule
