/* DCF77 register with Wishbone interface */

module dcf77_registers(if_wishbone.slave wb,
		       if_date_time      dcf77_date_time,
		       if_date_time      clock_date_time,
		       logic [3:0]       endp);

   logic [63:0] dcf77_data;
   logic [63:0] clock_data;

   always_comb
     begin
	dcf77_data[0]    =1'b0;
	dcf77_data[14:1] =dcf77_date_time.broadcast;
	dcf77_data[15]   =dcf77_date_time.r;
	dcf77_data[16]   =dcf77_date_time.a1;
	dcf77_data[17]   =dcf77_date_time.z1;
	dcf77_data[18]   =dcf77_date_time.z2;
	dcf77_data[19]   =dcf77_date_time.a2;
	dcf77_data[20]   =1'b1;
	dcf77_data[27:21]=dcf77_date_time.minute;
	dcf77_data[28]   =dcf77_date_time.p1;
	dcf77_data[34:29]=dcf77_date_time.hour;
	dcf77_data[35]   =dcf77_date_time.p2;
	dcf77_data[41:36]=dcf77_date_time.day;
	dcf77_data[44:42]=dcf77_date_time.day_of_week;
	dcf77_data[49:45]=dcf77_date_time.month;
	dcf77_data[57:50]=dcf77_date_time.year;
	dcf77_data[58]   =dcf77_date_time.p3;
	dcf77_data[63:59]=5'b0;

	clock_data[27:21]=clock_date_time.minute;
	clock_data[34:29]=clock_date_time.hour;
	clock_data[41:36]=clock_date_time.day;
	clock_data[44:42]=clock_date_time.day_of_week;
	clock_data[49:45]=clock_date_time.month;
	clock_data[57:50]=clock_date_time.year;
     end

   /* FSM for reading 64 bit dcf77_data sequentially. */
   enum int unsigned {S[8]} state,next;

   always_ff @(posedge wb.clk)
     if(wb.rst)
       state<=S0;
     else
       state<=next;

   always_comb
     begin
	next=state;

	if(wb.ack)
	  case(state)
	    S0: next=S1;
	    S1: next=S2;
	    S2: next=S3;
	    S3: next=S4;
	    S4: next=S5;
	    S5: next=S6;
	    S6: next=S7;
	    S7: next=S0;
	  endcase
     end

   always_comb
     case(state)
       S0:     wb.data_s<={5'b0,dcf77_data[58:56]};
       S1:     wb.data_s<=      dcf77_data[55:48];
       S2:     wb.data_s<=      dcf77_data[47:40];
       S3:     wb.data_s<=      dcf77_data[39:32];
       S4:     wb.data_s<=      dcf77_data[31:24];
       S5:     wb.data_s<=      dcf77_data[23:16];
       S6:     wb.data_s<=      dcf77_data[15: 8];
       S7:     wb.data_s<=      dcf77_data[ 7: 0];
       default wb.data_s<=8'bx;
     endcase

   /* synchronous slave */
   always_ff @(posedge wb.clk)
     if(wb.rst)
       wb.ack<=1'b0;
     else
       if(wb.ack)
	 wb.ack<=1'b0;
       else if(wb.cyc && wb.stb)
	 wb.ack<=1'b1;
endmodule
