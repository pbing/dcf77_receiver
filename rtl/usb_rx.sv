/* USB-2.0 low/full speed receiver */

module usb_rx(input              rstx, // system reset (low active)
	      input 		 clk, // system clock (low speed: 6 MHz, full speed: 48 MHz)
	      input 		 types::d_port_t d, // USB port D+,D-
	      output logic [7:0] data, // data to SIE
	      output logic 	 active, // active between SYNC und EOP
	      output logic 	 valid, // data valid pulse
	      output logic 	 error, // error detected
	      output 		 types::d_port_t line_state); // synchronized D+,D-

   import types::*;

   d_port_t    d_s[1:4]; // [1:2]=sync [2:4]=majority
   logic       j,k,se0;

   /* synchronize to system clock */
   always_ff @(posedge clk or negedge rstx)
     if(!rstx)
       for(int i=1;i<=4;i++)
	 d_s[i]<=J; // IDLE
     else
       begin
	  d_s[1]<=d;

	  for(int i=2;i<=4;i++)
	    d_s[i]<=d_s[i-1];
       end

   /* 2-of-3 majority */
   always_comb j  =(d_s[2]==J   && d_s[3]==J)   || (d_s[2]==J   && d_s[4]==J)   || (d_s[3]==J   && d_s[4]==J);
   always_comb k  =(d_s[2]==K   && d_s[3]==K)   || (d_s[2]==K   && d_s[4]==K)   || (d_s[3]==K   && d_s[4]==K);
   always_comb se0=(d_s[2]==SE0 && d_s[3]==SE0) || (d_s[2]==SE0 && d_s[4]==SE0) || (d_s[3]==SE0 && d_s[4]==SE0);

   always_comb line_state=d_s[2];

   /*************************************************************
    * DLL for synchronizing the sampling at the midpoint
    *************************************************************/

   /* detect rising edge of J or K */
   logic j_1,k_1,jk_edge;

   always_ff @(posedge clk or negedge rstx)
     if(!rstx)
       begin
	  j_1<=1'b0;
	  k_1<=1'b0;
       end
     else
       begin
	  j_1<=j;
	  k_1<=k;
       end

   always_comb jk_edge=(!j_1&&j) || (!k_1&&k) ;

   /* DLL FSM */
   enum logic [1:0] {DLLSTATE[4]} dll_state,dll_next;
   logic clk_en;

   always_ff @(posedge clk or negedge rstx)
     if(!rstx)
       dll_state<=DLLSTATE0;
     else
       dll_state<=dll_next;

   always_comb
     begin
	clk_en=1'b0;

	unique case(dll_state)
	  DLLSTATE0:
	    if(jk_edge)
	      dll_next=DLLSTATE0;
	    else
	      begin
		 clk_en=1'b1;
		 dll_next=DLLSTATE1;
	      end

	  DLLSTATE1:
	    if(jk_edge)
	      dll_next=DLLSTATE3;
	    else
	      dll_next=DLLSTATE2;

	  DLLSTATE2:
	    if(jk_edge)
	      dll_next=DLLSTATE0;
	    else
	      dll_next=DLLSTATE3;

	  DLLSTATE3:
	    dll_next=DLLSTATE0;

	  default
	    dll_next=DLLSTATE0;
	endcase
     end

   /*************************************************************
    * RX FSM
    *
    * Use dummy states to get a state number of powers of two.
    * Otherwise the synthesis software of Quartus will insert a
    * modulo-N divider because of rx_state.next().
    *************************************************************/
   enum logic [4:0] {RESET,SYNC[8],RX_DATA_WAIT[8],RX_DATA,STRIP_EOP[2],ERROR,ABORT[1:2],TERMINATE,DUMMY[8]} rx_state,rx_next;
   logic rcv_bit,rcv_data;

   always_ff @(posedge clk or negedge rstx)
     if(!rstx)
       rx_state<=RESET;
     else
       rx_state<=rx_next;

   always_comb
     begin
	rx_next=rx_state;
	active=1'b0;
	rcv_data=1'b0;
	error=1'b0;

	unique case(rx_state)
	  RESET:
	    if(clk_en && k) rx_next=SYNC0;

	  SYNC0,SYNC2,SYNC4:
	    if(clk_en && j) rx_next=rx_state.next();

	  SYNC1,SYNC3,SYNC5,SYNC6:
	    if(clk_en && k) rx_next=rx_state.next();

	  SYNC7:
	    if(clk_en && k) rx_next=RX_DATA_WAIT0;

	  RX_DATA_WAIT0,RX_DATA_WAIT1,RX_DATA_WAIT2,RX_DATA_WAIT3,
	    RX_DATA_WAIT4,RX_DATA_WAIT5,RX_DATA_WAIT6:
	      begin
		 active=1'b1;
		 if(rcv_bit) rx_next=rx_state.next();
	      end

	  RX_DATA_WAIT7:
	    begin
	       active=1'b1;
	       if(clk_en && se0)
		 rx_next=STRIP_EOP0;
	       else if(rcv_bit)
		 rx_next=RX_DATA;
	    end

	  RX_DATA:
	    begin
	       active=1'b1;
	       rcv_data=1'b1;
	       if(rcv_bit) rx_next=RX_DATA_WAIT1;
	    end

	  STRIP_EOP0:
	    begin
 	       active=1'b1;
	       rcv_data=1'b1;
	       if(clk_en) rx_next=STRIP_EOP1;
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
	       rcv_data=1'b1;
	       error=1'b1;
	       rx_next=ABORT1; // choose ABORT1 or ABORT2
	    end

	  ABORT1:
	    rx_next=RESET;

	  ABORT2:
	    begin
	       active=1'b1;
	       if(clk_en && j) // IDLE
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
   logic d0;
   logic [1:2] nrzi;

   always_ff @(posedge clk or negedge rstx)
     if(!rstx)
       nrzi<='0;
     else if(clk_en)
       begin
	  nrzi[1]<=j;
	  nrzi[2]<=nrzi[1];
       end

   always_comb d0<=~^nrzi;

   /* bit unstuffing */
   logic [2:0] num_ones;

   always_ff @(posedge clk or negedge rstx)
     if(!rstx)
       num_ones<='0;
     else if(clk_en)
       if(d0)
	 if(num_ones=='d6)
	   num_ones<='d0;
	 else
	   num_ones<=num_ones+3'd1;
       else
	 num_ones<='d0;

   /* zero when bit unstuffing */
   always_comb rcv_bit=(clk_en && (d0 || num_ones!='d6));


   /*
    * RX shift/hold register
    * valid signal
    */
   logic [7:0] rx_shift;

   always_ff @(posedge clk or negedge rstx)
     if(!rstx)
       begin
	  rx_shift<='0;
	  data<='0;
	  valid<='0;
       end
     else
       begin
	  /* RX shift register */
	  if(rcv_bit) rx_shift<={d0,rx_shift[7-:7]};

	  /* RX hold register */
	  if(clk_en & rcv_data) data<=rx_shift;

	  /* valid signal */
	  valid<=clk_en & rcv_data;
       end
endmodule
