/* USB low/full speed receiver */

module usb_rx
  import types::*;
   (input              reset,  // system reset
    input              clk,    // system clock (24 MHz)
    input              clk_en, // clock enable
    input  d_port_t    d_i,    // data from CDR
    output logic [7:0] data,   // data to SIE
    output logic       active, // active between SYNC und EOP
    output logic       valid,  // data valid pulse
    output logic       error); // error detected

   logic j,k,se0;

   always_comb j  =(d_i==J);
   always_comb k  =(d_i==K);
   always_comb se0=(d_i==SE0);

   /*************************************************************
    * RX FSM
    *
    * Use dummy states to get a state number of powers of two.
    * Otherwise the synthesis software of Quartus will insert a
    * modulo-N divider because of rx_state.next().
    *************************************************************/
   enum logic [4:0] {RESET,SYNC[8],RX_DATA_WAIT[8],RX_DATA,STRIP_EOP[2],ERROR,ABORT[1:2],TERMINATE,DUMMY[8]} rx_state,rx_next;
   logic rcv_bit,rcv_data;

   always_ff @(posedge clk)
     if(reset)
       rx_state<=RESET;
     else if(clk_en)
       rx_state<=rx_next;

   always_comb
     begin
	rx_next=rx_state;
	active=1'b0;
	rcv_data=1'b0;
	error=1'b0;

	unique case(rx_state)
	  RESET:
	    if(k) rx_next=SYNC0;

	  SYNC0,SYNC2,SYNC4:
	    if(j) rx_next=rx_state.next();
	    else  rx_next=RESET;

	  SYNC1,SYNC3,SYNC5,SYNC6:
	    if(k) rx_next=rx_state.next();
	    else  rx_next=RESET;

	  SYNC7:
	    rx_next=RX_DATA_WAIT0;

	  RX_DATA_WAIT0,RX_DATA_WAIT1,RX_DATA_WAIT2,RX_DATA_WAIT3,
	    RX_DATA_WAIT4,RX_DATA_WAIT5,RX_DATA_WAIT6:
	      begin
		 active=1'b1;
		 if(rcv_bit) rx_next=rx_state.next();
	      end

	  RX_DATA_WAIT7:
	    begin
	       active=1'b1;
	       rcv_data=1'b1;
	       if(se0)
		 rx_next=STRIP_EOP0;
	       else if(rcv_bit)
		 rx_next=RX_DATA;
	    end

	  RX_DATA:
	    begin
	       active=1'b1;
	       if(rcv_bit) rx_next=RX_DATA_WAIT1;
	    end

	  STRIP_EOP0:
	    begin
 	       active=1'b1;
	       rx_next=STRIP_EOP1;
	    end

	  STRIP_EOP1:
	    /* enable active for one more clock */
	    begin
 	       active=1'b1;
	       rx_next=RESET;
	    end

	  ERROR:
	    begin
	       active=1'b1;
	       error=1'b1;
	       rx_next=ABORT1; // choose ABORT1 or ABORT2
	    end

	  ABORT1:
	    rx_next=RESET;

	  ABORT2:
	    begin
	       active=1'b1;
	       if(j) // IDLE
		 rx_next=TERMINATE;
	    end

	  TERMINATE:
	    rx_next=RESET;

	  default
	    rx_next=RESET;
	endcase
     end

   /*************************************************************
    * NRZI decoding
    *************************************************************/
   logic nrzi,d0;

   always_ff @(posedge clk)
     if(reset)
       nrzi<=1'b0;
     else if(clk_en)
       nrzi<=j;

   always_comb d0<=j ~^ nrzi;

   /* bit unstuffing */
   logic [2:0] num_ones;

   always_ff @(posedge clk)
     if(reset)
       num_ones<=3'd0;
     else if(clk_en)
       if(d0)
	 if(num_ones==3'd6)
	   num_ones<=3'd0;
	 else
	   num_ones<=num_ones+3'd1;
       else
	 num_ones<=3'd0;

   /* zero when bit unstuffing */
   always_comb rcv_bit=(d0 || num_ones!=3'd6);

   /* RX shift/hold register */
   always_ff @(posedge clk)
     begin:rx_shift_hold
	logic [7:0] rx_shift;

	if(reset)
	  begin
	     rx_shift<=8'h0;
	     data    <=8'h0;
	  end
	else if(clk_en)
	  begin
	     /* RX shift register */
	     if(rcv_bit) rx_shift<={d0,rx_shift[7-:7]};

	     /* RX hold register */
	     if(rcv_data) data<=rx_shift;
	  end
     end:rx_shift_hold

   /* valid signal */
   always_ff @(posedge clk)
     if(reset)
       valid<=1'b0;
     else
       valid<=rcv_data & clk_en;
endmodule
