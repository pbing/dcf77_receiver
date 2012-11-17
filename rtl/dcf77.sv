/* DCF77 receiver */

module dcf77(input               rst,       // reset
	     input               clk,       // clock (24 MHz)
	     input               clk_en,    // clock enable (10 ms)
	     input               rx,        // pulse 100 ms=0, pulse 200 ms=1
	     output logic [58:0] data_hold, // data hold register
	     output logic        error,     // error flag
	     output logic        sync);     // synchronize clock

   logic [58:0] data_shift;       // data shift register
   logic        valid,data_valid; // received data frame is valid

   always_ff @(posedge clk)
     begin:main
	logic [0:3]  rx_s;                // [0:1]=synchronization, [1:3]=majority
	logic [0:1]  rx_d;                // rx data pipe
	logic [4:0]  counter_pulse;       // counter for pulse width (0=5'd10, 1=5'd20)
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
	     error<='1;
	     data_valid<='0;
	  end
	else if(clk_en)
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
		  d<=(counter_pulse<5'd15)?1'b0:1'b1; // Threshold is 0.15 seconds.
		  shift_en<=1'b1;
		  counter_pulse<=5'd0;
	       end

	     /* detect start */
	     counter_start[1]<=counter_start[1]+8'd1;
	     start<=1'b0;

	     if(rx_d==2'b10) // rising edge
	       begin
		  start<=(counter_start[1]-counter_start[2])>8'd150; // Delay greater than 1.5 seconds?
		  counter_start[2]<=counter_start[1];
	       end

	     /* shift register */
	     if(shift_en)
	       data_shift<={d,data_shift[58:1]};

	     /* hold register,error flag, data valid */
	     data_valid<=1'b0;

	     if(start)
	       begin
		  data_hold<=data_shift;
		  error<=!valid;
		  data_valid<=valid;
	       end
	  end
     end:main

   /* synchronization to external modules */
   always_comb sync=data_valid & clk_en;

   /* check validy of DCF77 frame */
   always_comb
     begin:validy_check
	logic p1,p2,p3;                   // parity flags
	logic start_of_minute,            // validy flags
	      start_of_encoding_times,
	      minutes,hours,day_of_month,
	      day_of_week,month,year;

	p1=~^data_shift[28:21]; // even parity over minutes
	p2=~^data_shift[35:29]; // even parity over hours
	p3=~^data_shift[58:36]; // even parity over date

	/* check validy */
	start_of_minute=!data_shift[0];
	start_of_encoding_times=data_shift[20];
	minutes     =(data_shift[27:25]<6 && data_shift[24:21]<10);
	hours       =(data_shift[34:33]<3 && data_shift[32:29]<10 && !(data_shift[34:33]==2 && data_shift[32:29]>3));
	day_of_month=(data_shift[39:36]<10 && !(data_shift[41:40]==3 && data_shift[39:36]>1));
	day_of_week =(data_shift[44:42]>0 && data_shift[44:42]<8);
	month       =(data_shift[48:45]<10 && !(data_shift[49]==1 && data_shift[48:45]>2));
	year        =(data_shift[57:54]<10 && data_shift[53:50]<10);

	valid=(p1 && p2 && p3 &&
	       start_of_minute && start_of_encoding_times &&
	       minutes && hours &&
	       day_of_month && day_of_week &&
	       month && year);
     end:validy_check
endmodule
