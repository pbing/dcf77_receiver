/* USB Low Speed sender */

module usb_tx
  import types::*;
   (input           reset,  // reset
    input           clk,    // system clock (24 MHz)
    output d_port_t d_o,    // USB port D+,D- (output)
    output logic    d_en,   // USB port D+,D- (enable)
    input  [7:0]    data,   // data from SIE
    input           valid,  // rise:SYNC,1:send data,fall:EOP
    output logic    ready); // data has been sent

   /* bit/byte enable */
   logic [3:0] bit_counter;  // 24 MHz/1.5 MHz=16
   logic [2:0] byte_counter; // 8 bits per byte
   logic       stuffing;     // bit stuffing
   logic [2:0] num_ones;     // number of ones
   logic       en_bit;       // enable bit

   enum logic [2:0] {RESET,TX_WAIT,SEND_SYNC,TX_DATA_LOAD,TX_DATA_WAIT,SEND_EOP} tx_state,tx_next;

   always_ff @(posedge clk)
     if(reset)
       begin
	  bit_counter <=4'd0;
	  byte_counter<=3'd0;
       end
     else
       begin
	  if(tx_state==RESET || (!valid && tx_state==TX_WAIT))
	    begin
	       bit_counter <=4'd0;
	       byte_counter<=3'd0;
	    end
	  else
	    begin
	       bit_counter<=bit_counter+2'd1;

	       if(bit_counter==4'd15 && !stuffing)
		 byte_counter<=byte_counter+3'd1;
	    end
       end

   always_comb
     begin
        en_bit=(tx_state!=RESET && tx_state!=TX_WAIT && bit_counter==4'd0);
	ready =(en_bit && byte_counter==3'd7 && !stuffing);
     end

   /* TX FSM */
   always_ff @(posedge clk)
     if(reset)
       tx_state<=RESET;
     else
       tx_state<=tx_next;

   always_comb
     begin
	d_en   =1'b0;
	tx_next=tx_state;

	case(tx_state)
	  RESET:
	    if(!reset) tx_next=TX_WAIT;

	  TX_WAIT:
	    if(valid) tx_next=SEND_SYNC;

	  SEND_SYNC:
	    begin
	       d_en=1'b1;
	       if(ready) tx_next=TX_DATA_LOAD;
	    end

	  TX_DATA_LOAD:
	    begin
	       d_en=1'b1;
	       if(valid && en_bit && !stuffing) tx_next=TX_DATA_WAIT;
	       if(!valid && byte_counter==3'd1) tx_next=SEND_EOP;
	    end

	  TX_DATA_WAIT:
	    begin
	       d_en=1'b1;
	       if(ready) tx_next=TX_DATA_LOAD;
	    end

	  SEND_EOP:
	    begin
	       d_en=1'b1;
	       if(en_bit && byte_counter==3'd4) tx_next=TX_WAIT;
	    end

	  default tx_next=RESET;
	endcase
     end

   /* TX load/shift register */
   logic [7:0] tx_load,tx_shift;

   always_ff @(posedge clk)
     if(reset)
       tx_load<=8'b0;
     else if(ready)
       tx_load<=data;

   always_ff @(posedge clk)
     if(reset)
       tx_shift<=8'b0;
     else
       if(valid && tx_state==TX_WAIT)
	 tx_shift<=8'b10000000;             // SYNC pattern
       else if(en_bit && !stuffing)
	 if(tx_state==TX_DATA_LOAD)
	   tx_shift<=tx_load;               // load
	 else
	   tx_shift<={1'bx,tx_shift[7-:7]}; // shift

   /* bit stuffing */
   logic tx_serial;

   always_ff @(posedge clk) // FIXME
     if(reset)
       num_ones<=3'd0;
     else if(en_bit)
       if(tx_shift[0])
	 if(stuffing)
	   num_ones<=3'd0;
	 else
	   num_ones<=num_ones+3'd1;
       else
	 num_ones<=3'd0;

   always_comb
     begin
	stuffing =(num_ones==3'd6);
	tx_serial=(stuffing)?1'b0:tx_shift[0];
     end

   /* NRZI coding */
   logic nrzi;

   always_ff @(posedge clk)
     if(reset)
       nrzi<=1'b0;
     else if(en_bit)
       nrzi<=tx_serial^~nrzi;

   /* assign D+,D- */
   always_comb
     if(tx_state==SEND_EOP)
       /* two bit SE0, one bit J */
       begin
	  if(byte_counter<3'd3)
	    d_o=SE0;
	  else
	    d_o=J;
       end
     else if(tx_state==TX_WAIT)
       d_o=J;
     else
       d_o=(nrzi)?K:J;
endmodule
