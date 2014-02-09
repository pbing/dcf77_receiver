/* Shared bus Wishbone interconnection with one master and multiple slaves.
 * 
 *  RULE 3.20: RST_I,CLK_I -> STB_O=0, CYC_O=0
 * 
 *  RULE 3.55
 *  MASTER interfaces MUST be designed to operate normally when the SLAVE interface holds [ACK_I] in the asserted state.
 * 
 *  RULE 3.60
 *  MASTER interfaces MUST qualify the following signals with [STB_O]: [ADR_O], [DAT_O()], [SEL_O()], [WE_O], and [TAGN_O].
 * 
 *  RULE 3.65
 *  SLAVE interfaces MUST qualify the following signals with [ACK_O], [ERR_O] or [RTY_O]: [DAT_O()].
 * 
 *  RULE 4.00
 *  All WISHBONE Registered Feedback compatible cores MUST support WISHBONE Classic bus cycles.
 */

module wb_shared_bus #(parameter n=4) // don't change it during instantiation
   (if_wishbone.slave  wbm,
    if_wishbone.master wbs[n]);

   generate
      begin:gen
	 genvar i;

	 for(i=0;i<n;i++)
	   begin:loop
	      assign wbs[i].data_m=wbm.data_m;
	      assign wbs[i].addr  =wbm.addr;
	      assign wbs[i].cyc   =wbm.cyc;
	      assign wbs[i].stb   =wbm.stb; // fully address decoding needed by slave
	      assign wbs[i].we    =wbm.we;
	   end:loop
      end:gen
   endgenerate

   /* This can't be written as function of parameter n. */
   always_comb
     begin:mux
	wbm.data_s='x;
	wbm.ack   ='x;

	case(wbm.addr)
	  2'h0:
	    begin
	       wbm.data_s=wbs[0].data_s;
	       wbm.ack   =wbs[0].ack;
	    end
	  2'h1:
	    begin
	       wbm.data_s=wbs[1].data_s;
	       wbm.ack   =wbs[1].ack;
	    end
/* -----\/----- EXCLUDED -----\/-----
	  2'h2:
	    begin
	       wbm.data_s=wbs[2].data_s;
	       wbm.ack   =wbs[2].ack;
	    end
	  2'h3:
	    begin
	       wbm.data_s=wbs[3].data_s;
	       wbm.ack   =wbs[3].ack;
	    end
 -----/\----- EXCLUDED -----/\----- */
	endcase
     end:mux
endmodule
