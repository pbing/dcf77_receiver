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
    * Use exlicite state assings instead of rx_next=rx_state.next()
    * because automatic FSM detection of Synplify does not work
    * in this case.
    *************************************************************/
   enum int unsigned {RESET,SYNC[8],RX_DATA_WAIT[8],RX_DATA,STRIP_EOP[2],ERROR,ABORT[1:2],TERMINATE} rx_state,rx_next;
   logic             rcv_bit,rcv_data;

   always_ff @(posedge clk)
     if(reset)
       rx_state<=RESET;
     else if(clk_en)
       rx_state<=rx_next;

   always_comb
     begin
	rx_next=rx_state;

	case(rx_state)
	  RESET:
	    if(k) rx_next=SYNC0;

	  SYNC0:
	    if(j) rx_next=SYNC1;
	    else  rx_next=RESET;

	  SYNC1:
	    if(k) rx_next=SYNC2;
	    else  rx_next=RESET;

	  SYNC2:
	    if(j) rx_next=SYNC3;
	    else  rx_next=RESET;

	  SYNC3:
	    if(k) rx_next=SYNC4;
	    else  rx_next=RESET;


	  SYNC4:
	    if(j) rx_next=SYNC5;
	    else  rx_next=RESET;

	  SYNC5:
	    if(k) rx_next=SYNC6;
	    else  rx_next=RESET;

	  SYNC6:
	    if(k) rx_next=SYNC7;
	    else  rx_next=RESET;

	  SYNC7:
	    rx_next=RX_DATA_WAIT0;

	  RX_DATA_WAIT0:
	    if(rcv_bit) rx_next=RX_DATA_WAIT1;

	  RX_DATA_WAIT1:
	    if(rcv_bit) rx_next=RX_DATA_WAIT2;

	  RX_DATA_WAIT2:
	    if(rcv_bit) rx_next=RX_DATA_WAIT3;

	  RX_DATA_WAIT3:
	    if(rcv_bit) rx_next=RX_DATA_WAIT4;

	  RX_DATA_WAIT4:
	    if(rcv_bit) rx_next=RX_DATA_WAIT5;

	  RX_DATA_WAIT5:
	    if(rcv_bit) rx_next=RX_DATA_WAIT6;

	  RX_DATA_WAIT6:
	    if(rcv_bit) rx_next=RX_DATA_WAIT7;

	  RX_DATA_WAIT7:
	    if(se0)
	      rx_next=STRIP_EOP0;
	    else if(rcv_bit)
	      rx_next=RX_DATA;

	  RX_DATA:
	    if(rcv_bit) rx_next=RX_DATA_WAIT1;

	  STRIP_EOP0:
	    rx_next=STRIP_EOP1;

	  STRIP_EOP1:
	    rx_next=RESET;

	  ERROR:
	    rx_next=ABORT1; // choose ABORT1 or ABORT2

	  ABORT1:
	    rx_next=RESET;

	  ABORT2:
	    if(j) // IDLE
	      rx_next=TERMINATE;

	  TERMINATE:
	    rx_next=RESET;

	  default
	    rx_next=RESET;
	endcase
     end

   always_comb
     begin
	active  =(rx_state!=RESET || rx_state!=SYNC0 || rx_state!=SYNC1 || 
		  rx_state!=SYNC2 || rx_state!=SYNC3 || rx_state!=SYNC4 || 
		  rx_state!=SYNC5 || rx_state!=SYNC6 || rx_state!=SYNC7);
	rcv_data=(rx_state==RX_DATA_WAIT7);	
	error   =(rx_state==ERROR);
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
