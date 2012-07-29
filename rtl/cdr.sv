/* Oversampled Hogge clock and data recovery circuit */

module cdr(input                  reset,   // system reset
	   input                  clk,     // system clock (24 MHz)
	   input  types::d_port_t d,       // data from PHY
	   output types::d_port_t q,       // retimed data
	   output logic           strobe); // data strobe

   import types::*;
   
   logic [3:0]        phase;        // phase (24 MHz/1.5 MHz=16)
   logic signed [4:0] dphase;       // delta phase
   var d_port_t       d_shift[1:2]; // shifted data
   logic              up,down;      // phase shift direction

   always @(posedge clk)
     if(reset)
       begin
	  d_shift[1]<=J;
	  d_shift[2]<=J;
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
		 else
		   /* skip phase increment when dphase is negative */
		   phase<=phase;

		 if(!(up||down))
		   dphase<=5'sd0;
	      end

	    default
	      phase<=phase+5'sd1;
	  endcase
       end

   always_comb
     begin
	/* Phase discriminators are using only one bit (d_port_t[0]). */
	down=(d_shift[1][0]!=d_shift[2][0]);
	up=(d[0]!=d_shift[1][0]);

	q=d_shift[2];
	strobe=(phase==4'd12);
     end
endmodule
