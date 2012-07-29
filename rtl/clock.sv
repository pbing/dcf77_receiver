/* Clock */

module clock(input  rst,    // reset
	     input  clk,    // clock (24 MHz)
	     input  clk_en, // clock enable (10 ms)

	     /* from DCF77 module */
	     input                     dcf77_sync,
	     input  types::bcd_t [1:0] dcf77_year,
	     input  types::bcd_t [1:0] dcf77_month,
	     input  types::bcd_t [1:0] dcf77_day,
	     input               [2:0] dcf77_day_of_week,
	     input  types::bcd_t [1:0] dcf77_hour,
	     input  types::bcd_t [1:0] dcf77_minute,

	     /* synchronized free running clock */
	     output types::bcd_t [1:0] year,
	     output types::bcd_t [1:0] month,
	     output types::bcd_t [1:0] day,
	     output logic        [2:0] day_of_week,
	     output types::bcd_t [1:0] hour,
	     output types::bcd_t [1:0] minute,
	     output types::bcd_t [1:0] second);

   import types::bcd_t;

   always_ff @(posedge clk)
     begin:main
	logic [6:0] counter;

	if(rst)
	  begin
	     counter<='0;
	     year<='0;
	     month<={bcd_t'(0),bcd_t'(1)};
	     day<={bcd_t'(0),bcd_t'(1)};
	     day_of_week<=3'd1;
	     hour<='0;
	     minute<='0;
	     second<='0;
	  end
	else if(clk_en)
	  begin
	     if(dcf77_sync)
	       begin
		  counter<=7'd7; // try to synchronize of rising edge of DCF77-RX
		  year<=dcf77_year;
		  month<=dcf77_month;
		  day<=dcf77_day;
		  day_of_week<=dcf77_day_of_week;
		  hour<=dcf77_hour;
		  minute<=dcf77_minute;
		  second<='0;
	       end
	     else
	       begin
		  logic january,february,march,april,may,june,july,august,september,october,november,december,
		 leap_year,month_has_28_days,month_has_29_days,month_has_30_days,month_has_31_days,
		 last_tick,last_second,last_minute,last_hour,last_day,last_month,last_year;

		  january  =month[1]==bcd_t'(0) && month[0]==bcd_t'(1);
		  february =month[1]==bcd_t'(0) && month[0]==bcd_t'(2);
		  march    =month[1]==bcd_t'(0) && month[0]==bcd_t'(3);
		  april    =month[1]==bcd_t'(0) && month[0]==bcd_t'(4);
		  may      =month[1]==bcd_t'(0) && month[0]==bcd_t'(5);
		  june     =month[1]==bcd_t'(0) && month[0]==bcd_t'(6);
		  july     =month[1]==bcd_t'(0) && month[0]==bcd_t'(7);
		  august   =month[1]==bcd_t'(0) && month[0]==bcd_t'(8);
		  september=month[1]==bcd_t'(0) && month[0]==bcd_t'(9);
		  october  =month[1]==bcd_t'(1) && month[0]==bcd_t'(0);
		  november =month[1]==bcd_t'(1) && month[0]==bcd_t'(1);
		  december =month[1]==bcd_t'(1) && month[0]==bcd_t'(2);

		  leap_year=(year[1]==bcd_t'(0) && year[0]==bcd_t'(4)) ||
			    (year[1]==bcd_t'(0) && year[0]==bcd_t'(8)) ||
			    (year[1]==bcd_t'(1) && year[0]==bcd_t'(2)) ||
			    (year[1]==bcd_t'(1) && year[0]==bcd_t'(6)) ||
			    (year[1]==bcd_t'(2) && year[0]==bcd_t'(0)) ||
			    (year[1]==bcd_t'(2) && year[0]==bcd_t'(4)) ||
			    (year[1]==bcd_t'(2) && year[0]==bcd_t'(8)) ||
			    (year[1]==bcd_t'(3) && year[0]==bcd_t'(2)) ||
			    (year[1]==bcd_t'(3) && year[0]==bcd_t'(6)) ||
			    (year[1]==bcd_t'(4) && year[0]==bcd_t'(0)) ||
			    (year[1]==bcd_t'(4) && year[0]==bcd_t'(4)) ||
			    (year[1]==bcd_t'(4) && year[0]==bcd_t'(8)) ||
			    (year[1]==bcd_t'(5) && year[0]==bcd_t'(2)) ||
			    (year[1]==bcd_t'(5) && year[0]==bcd_t'(6)) ||
			    (year[1]==bcd_t'(6) && year[0]==bcd_t'(0)) ||
			    (year[1]==bcd_t'(6) && year[0]==bcd_t'(4)) ||
			    (year[1]==bcd_t'(6) && year[0]==bcd_t'(8)) ||
			    (year[1]==bcd_t'(7) && year[0]==bcd_t'(2)) ||
			    (year[1]==bcd_t'(7) && year[0]==bcd_t'(6)) ||
			    (year[1]==bcd_t'(8) && year[0]==bcd_t'(0)) ||
			    (year[1]==bcd_t'(8) && year[0]==bcd_t'(4)) ||
			    (year[1]==bcd_t'(8) && year[0]==bcd_t'(8)) ||
			    (year[1]==bcd_t'(9) && year[0]==bcd_t'(2)) ||
			    (year[1]==bcd_t'(9) && year[0]==bcd_t'(6));

		  month_has_28_days=february && !leap_year;
		  month_has_29_days=february && leap_year;
		  month_has_30_days=april || june || september || november;
		  month_has_31_days=january || march || may || july || august || october || december;

		  last_tick  =counter==7'd99;
		  last_second=second[1]==bcd_t'(5) && second[0]==bcd_t'(9);
		  last_minute=minute[1]==bcd_t'(5) && minute[0]==bcd_t'(9);
		  last_hour  =  hour[1]==bcd_t'(2) && hour[0]==bcd_t'(3);
		  last_day   =(month_has_28_days && day[1]==bcd_t'(2) && day[0]==bcd_t'(8)) ||
			      (month_has_29_days && day[1]==bcd_t'(2) && day[0]==bcd_t'(9)) ||
			      (month_has_30_days && day[1]==bcd_t'(3) && day[0]==bcd_t'(0)) ||
			      (month_has_31_days && day[1]==bcd_t'(3) && day[0]==bcd_t'(1));
		  last_month = month[1]==bcd_t'(1) && month[0]==bcd_t'(2);
		  last_year  =  year[1]==bcd_t'(9) &&  year[0]==bcd_t'(9);

		  /* 1 second counter */
		  if(last_tick)
		    counter<=7'd0;
		  else
		    counter<=counter+7'd1;

		  if(last_tick)
		    begin:count_seconds
		       /* second */
		       second[0]<=second[0]+bcd_t'(1);

		       if(second[0]==bcd_t'(9))
			 begin
			    second[0]<=bcd_t'(0);
			    second[1]<=second[1]+bcd_t'(1);
			 end

		       if(last_second)
			 second[1]<=bcd_t'(0);

		       /* minute */
		       if(last_second)
			 begin:count_minutes
			    minute[0]<=minute[0]+bcd_t'(1);

			    if(minute[0]==bcd_t'(9))
			      begin
				 minute[0]<=bcd_t'(0);
				 minute[1]<=minute[1]+bcd_t'(1);
			      end

			    if(last_minute)
			      minute[1]<=bcd_t'(0);
			 end:count_minutes

		       /* hour */
		       if(last_minute && last_second)
			 begin:count_hours
			    hour[0]<=hour[0]+bcd_t'(1);

			    if(hour[0]==bcd_t'(9))
			      begin
				 hour[0]<=bcd_t'(0);
				 hour[1]<=hour[1]+bcd_t'(1);
			      end

			    if(last_hour)
			      begin
				 hour[0]<=bcd_t'(0);
				 hour[1]<=bcd_t'(0);
			      end
			 end:count_hours

		       /* days */
		       if(last_hour && last_minute && last_second)
			 begin:count_days
			    day_of_week<=day_of_week+3'd1;
			    day[0]<=day[0]+bcd_t'(1);

			    if(day_of_week==3'd7)
			      day_of_week<=3'd1;

			    if(day[0]==bcd_t'(9))
			      begin
				 day[0]<=bcd_t'(0);
				 day[1]<=day[1]+bcd_t'(1);
			      end

			    if(last_day)
			      begin
				 day[0]<=bcd_t'(1);
				 day[1]<=bcd_t'(0);
			      end
			 end:count_days

		       /* months */
		       if(last_day && last_hour && last_minute && last_second)
			 begin:count_months
			    month[0]<=month[0]+bcd_t'(1);

			    if(month[0]==bcd_t'(9))
			      begin
				 month[0]<=bcd_t'(0);
				 month[1]<=month[1]+bcd_t'(1);
			      end

			    if(last_month)
			      begin
				 month[0]<=bcd_t'(1);
				 month[1]<=bcd_t'(0);
			      end
			 end:count_months

		       /* years */
		       if(last_month && last_day && last_hour && last_minute && last_second)
			 begin:count_years
			    year[0]<=year[0]+bcd_t'(1);

			    if(year[0]==bcd_t'(9))
			      begin
				 year[0]<=bcd_t'(0);
				 year[1]<=year[1]+bcd_t'(1);
			      end

			    if(last_year)
			      year[1]<=bcd_t'(0);
			 end:count_years
		    end:count_seconds
	       end
	  end
     end
endmodule
