/* I/O interface to the J1 processor core */

module io_interface(input   reset,
		    input   clk,
		    if_io   io,
		    if_fifo endpi0,
		    if_fifo endpo0,
		    if_fifo endpi1);

   localparam [15:0]
     /* LED */
     LEDG          =16'h4000,
     LEDR          =16'h4002,
     /* HEX display */
     HEX0          =16'h4010,
     HEX1          =16'h4012,
     HEX2          =16'h4014,
     HEX3          =16'h4016,
     /* keys and switches */
     KEY           =16'h4020,
     SW            =16'h4022,
     /* USB register */
     ENDPI0_DATA   =16'h5000,
     ENDPI0_STATUS =16'h5002,
     ENDPO0_DATA   =16'h5004,
     ENDPO0_STATUS =16'h5006,
     ENDPI1_DATA   =16'h5008,
     ENDPI1_STATUS =16'h500a;


   always_comb
     begin
	io.din      = '0;
	endpi0.data =io.dout[7:0];
	endpi1.data =io.dout[7:0];
	endpo0.rdreq=1'b0;
	endpi0.wrreq=1'b0;
	endpi1.wrreq=1'b0;

	if(io.rd)
	  case(io.addr)
	    ENDPO0_DATA:
	      begin
		 io.din[7:0] =endpo0.q;
		 endpo0.rdreq=1'b1;
	      end

	    ENDPI0_STATUS: io.din[0]=endpi0.full;
	    ENDPO0_STATUS: io.din[0]=endpo0.empty;
	    ENDPI1_STATUS: io.din[0]=endpi1.full;
	  endcase

	if(io.wr)
	  case(io.addr)
	    ENDPI0_DATA: endpi0.wrreq=1'b1;
	    ENDPI1_DATA: endpi1.wrreq=1'b1;
	  endcase
     end
endmodule
