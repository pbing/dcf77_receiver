/* Oversampled Hogge clock and data recovery circuit */

module cdr(input        reset,   // system reset
	   input        clk,     // system clock (24 MHz)
	   input        d,       // data from PHY
	   output logic q,       // retimed data
	   output logic strobe); // data strobe

   logic [3:0]        phase;   // phase (24 MHz/1.5 MHz=16)
   logic signed [4:0] dphase;  // delta phase
   logic [1:2]        d_shift; // shifted data
   logic              up,down; // phase shift direction

   always @(posedge clk)
     if(reset)
       begin
	  d_shift<='0;
	  phase<=4'd0;
	  dphase<=5'sd0;
       end
     else
       begin
	  if(down)
	    dphase<=dphase-5'sd1;
	  else if(up)
	    dphase<=dphase+5'sd1;

	  unique case(phase)
	    4'd4:
	      begin
		 d_shift[1]<=d;
		 phase<=phase+5'sd1;
	      end

	    4'd12:
	      begin
		 d_shift[2]<=d_shift[1];
		 phase<=phase+5'sd1;
	      end

	    4'd13:
	      begin
		 if(dphase==5'sd0)
		   phase<=phase+5'sd1;
		 else if(dphase>5'sd0)
		   phase<=phase+5'sd2;
		 /* skip phase increment when dphase is negative */

		 if(!(up||down))
		   dphase<=5'sd0;
	      end

	    default
	      phase<=phase+5'sd1;
	  endcase
       end

   always_comb
     begin
	down=d_shift[1]^d_shift[2];
	up=d^d_shift[1];
	q=d_shift[2];
	strobe=(phase==4'd12);
     end
endmodule