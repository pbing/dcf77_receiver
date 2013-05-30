/* Decoder for HEX display */

module display_decoder
  import types::*;
   (input        [2:0]  SW,          // Toggle Switch[2:0]
    if_date_time        clock,       // from clock module
    output logic [6:0]  HEX0,        // Seven Segment Digit 0
    output logic [6:0]  HEX1,        // Seven Segment Digit 1
    output logic [6:0]  HEX2,        // Seven Segment Digit 2
    output logic [6:0]  HEX3);       // Seven Segment Digit 3

   /* Switch control for 7-segment display */
   always_comb
     priority case(1'b1)
       SW[0]:
	 begin
	    HEX3=bcd_digit(0);
	    HEX2=bcd_digit(0);
	    HEX1=bcd_digit(clock.second[1]);
	    HEX0=bcd_digit(clock.second[0]);
	 end

       SW[1]:
	 begin
	    {HEX3,HEX2}=week_day_chars(clock.day_of_week);
	    HEX1=bcd_digit(clock.day[1]);
	    HEX0=bcd_digit(clock.day[0]);
	 end

       SW[2]:
	 begin
	    HEX3=bcd_digit(clock.year[1]);
	    HEX2=bcd_digit(clock.year[0]);
	    HEX1=bcd_digit(clock.month[1]);
	    HEX0=bcd_digit(clock.month[0]);
	 end

       default
	 begin
	    HEX3=bcd_digit(clock.hour[1]);
	    HEX2=bcd_digit(clock.hour[0]);
	    HEX1=bcd_digit(clock.minute[1]);
	    HEX0=bcd_digit(clock.minute[0]);
	 end
     endcase

   /********************************************************************************
    * Functions
    ********************************************************************************/

   /* HEX display digit
    *      A
    *    F   B
    *      G
    *    E   C
    *      D
    */
   function [6:0] bcd_digit(input bcd_t i);
      bit [6:0] digit['h10]='{/*  GFEDCBA */
			      ~7'b0111111,  // 0
			      ~7'b0000110,  // 1
			      ~7'b1011011,  // 2
			      ~7'b1001111,  // 3
			      ~7'b1100110,  // 4
			      ~7'b1101101,  // 5
			      ~7'b1111101,  // 6
			      ~7'b0000111,  // 7
			      ~7'b1111111,  // 8
			      ~7'b1101111,  // 9
			      ~7'b1110111,  // A
			      ~7'b1111100,  // b
			      ~7'b0111001,  // C
			      ~7'b1011110,  // d
			      ~7'b1111001,  // E
			      ~7'b1110001}; // F
      bcd_digit=digit[i];
   endfunction

   function [13:0] week_day_chars(input [2:0] i);
      bit [13:0] week_day[8]='{/*   GFEDCBA_GFEDCBA */
			       ~14'b1000000_1000000,  // --
			       ~14'b0110111_1011100,  // Mo
			       ~14'b1111000_0011100,  // tu
			       ~14'b0111110_1111001,  // WE
			       ~14'b1111000_1110100,  // th
			       ~14'b1110001_1010000,  // Fr
			       ~14'b1101101_1110111,  // SA
                               ~14'b1101101_1011100}; // So
      week_day_chars=week_day[i];
   endfunction
endmodule
