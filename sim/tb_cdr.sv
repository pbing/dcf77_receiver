module tb_cdr;
   timeunit 1ns;
   timeprecision 1ps;

   const realtime tclk=1s/24.0e6,
		  tbit=1s/1.5e6;

   bit rst=1;
   bit clk;
   bit d;
   wire q;
   wire strobe;

   cdr cdr(.*);

   initial forever #(tclk/2) clk=~clk;

   initial
     begin
	rst<=#(2*tclk) 1'b0;
	d=0;

	//#0.94us; // phase<0
	//#1.23us; // phase=0
	#1.60us; // phase>0

	/* SYNC */
	repeat(7) #tbit d=~d;
	#(2*tbit);

	repeat(64) #tbit d=$random;

	#100ns $stop;
     end
endmodule
