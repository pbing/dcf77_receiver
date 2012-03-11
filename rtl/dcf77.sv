/* DCF77 receiver */

module dcf77(input               rst,       // reset
	     input               clk,       // clock (24 MHz)
	     input               rx,        // pulse 100 ms=0, pulse 200 ms=1
	     output logic [58:0] data_hold, // data hold register
	     output logic        error);    // error flag

   logic [17:0] count_10ms;
   logic        en_10ms;
   
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
     begin:main
	logic [0:3]  rx_s;                // [0:1]=synchronization, [1:3]=majority
	logic [0:1]  rx_d;                // rx data pipe
	logic [58:0] data_shift;          // data shift register
	logic [4:0]  counter_pulse;       // counter for pulse width
	logic        d;                   // serial data
	logic        shift_en;            // shift enable
	logic [7:0]  counter_start[1:2];  // counter for start detection
	logic        start;               // start of frame
	
	if(rst)
	  begin
	     rx_s<='0;
	     rx_d<='0;
	     counter_pulse<='0;
	     d<='0;
	     shift_en<='0;
	     counter_start[1]<='0;
	     counter_start[2]<='0;
	     start<='0;
	     data_shift<='0;
	     data_hold<='0;
	  end
	else if(en_10ms)
	  begin
	     /* synchronization */
	     rx_s<={rx,rx_s[0:2]};

	     /* 2-of-3 majority */
	     rx_d[0]<=(rx_s[1] && rx_s[2]) || (rx_s[2] && rx_s[3]) || (rx_s[1] && rx_s[3]);
	     rx_d[1]<=rx_d[0];
	     
	     /* detect 0/1 */
	     shift_en<=1'b0;

	     if(rx_d==2'b11) // level 1
	       counter_pulse<=counter_pulse+5'd1;
	     else if(rx_d==2'b01) // falling edge
	       begin
		  d<=(counter_pulse<'d15)?1'b0:1'b1;
		  shift_en<=1'b1;
		  counter_pulse<='0;
	       end
	     
	     /* detect start */
	     start<=1'b0;
	     counter_start[1]<=counter_start[1]+8'd1;
	     
	     if(rx_d==2'b10) // rising edge
	       begin
		  start<=(counter_start[1]-counter_start[2])>8'd150; // Delay greater than 1.5 seconds?
		  counter_start[2]<=counter_start[1];
	       end

	     /* shift register */
	     if(shift_en)
	       data_shift<={d,data_shift[58:1]};
	     
	     if(start) 
	       data_hold<=data_shift;
	  end
     end
   
   /* error detection */
   always_comb
     begin:error_detection
	logic p1,p2,p3;                   // parity information
	logic minutes,hours,day_of_month, // check validy
	      day_of_week,month,year;
	
	p1=~^data_hold[28:21]; // even parity over minutes
	p2=~^data_hold[35:29]; // even parity over hours
	p3=~^data_hold[58:36]; // even parity over date

	minutes     =(data_hold[27:25]<6 && data_hold[24:21]<10); 
	hours       =(data_hold[34:33]<3 && data_hold[32:29]<10); 
	day_of_month=(data_hold[41:40]<3 && data_hold[39:36]<10); 
	day_of_week =(data_hold[44:42]>0 && data_hold[44:42]<8);
	month       =(data_hold[48:45]<10);
	year        =(data_hold[57:54]<10 && data_hold[53:50]<10); 

	error=!(p1 && p2 && p3 && 
		minutes && hours && day_of_month && day_of_week && month && year);
     end
endmodule
