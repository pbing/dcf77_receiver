/* DCF77 receiver */

module dcf77(input               rst,      // reset
	     input               clk,      // clock (24 MHz)
	     input               rx,       // pulse 100 ms=0, pulse 200 ms=1
	     output logic [58:0] data_hold,
	     output logic [6:0]  second,
	     output logic [6:0]  minute,
	     output logic [5:0]  hour,
	     output logic [5:0]  day,
	     output logic [2:0]  week_day,
	     output logic [4:0]  month,
	     output logic [7:0]  year,
	     output logic        error); 

   logic [17:0] count_10ms;
   logic        en_10ms;
   logic [0:3]  rx_s;           // [0:1]=synchronization, [1:3]=majority
   logic [0:1]  rx_pulse;
   logic [58:0] data_shift;
   logic [4:0]  counter_pulse;
   logic        pulse,shift_en;
   logic [7:0]  counter_delay[1:2];
   logic        start;
   
   /* 10ms*/
   always_ff @(posedge clk)
     if(rst)
       count_10ms<='0;
     else if(count_10ms==18'd239999)
       count_10ms<='0;
     else
       count_10ms<=count_10ms+18'd1;
   
   always_comb
     en_10ms=(count_10ms==18'd239999);

   always_ff @(posedge clk)
     if(rst)
       begin
	  rx_s<='0;
	  rx_pulse<='0;
	  counter_pulse<='0;
	  counter_delay[1]<='0;
	  counter_delay[2]<='0;
	  start<='0;
	  data_shift<='0;
	  data_hold<='0;
	  data_hold[58]<=1'b1; // force parity error
       end
     else if(en_10ms)
       begin
	  /* synchronization */
	  rx_s<={rx,rx_s[0:2]};

	  /* 2-of-3 majority */
	  rx_pulse[0]<=(rx_s[1] && rx_s[2]) || (rx_s[2] && rx_s[3]) || (rx_s[1] && rx_s[3]);
	  rx_pulse[1]<=rx_pulse[0];
	  shift_en<=1'b0;
	  
	  /* detect 0/1 */
	  if(rx_pulse==2'b11)
	    counter_pulse<=counter_pulse+5'd1;
	  else if(rx_pulse==2'b01)
	    begin
	       pulse<=(counter_pulse<'d15)?1'b0:1'b1;
	       shift_en<=1'b1;
	       counter_pulse<='0;
	    end
	  
	  /* detect start */
	  start<=1'b0;
	  counter_delay[1]<=counter_delay[1]+8'd1;
	  
	  if(rx_pulse==2'b10)
	    begin
	       start<=(counter_delay[1]-counter_delay[2])>8'd150;
	       counter_delay[2]<=counter_delay[1];
	    end

	  /* shift register */
	  if(shift_en)
	    data_shift<={pulse,data_shift[58:1]};
	  
	  if(start) 
	    data_hold<=data_shift;
       end

   /* error detection */
   always_comb
     begin
	logic p1,p2,p3;
	
	p1=~^data_hold[28:21]; // parity minutes
	p2=~^data_hold[35:29]; // parity hours
	p3=~^data_hold[58:36]; // parity date
	error=!(p1 && p2 && p3);
     end
endmodule
