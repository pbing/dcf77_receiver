/* 10 ms clock enable */

module clk_en(input        rst,     // reset
	      input        clk,     // clock (24 MHz)
	      output logic clk_en); // 10 ms clock enable

   logic [17:0] count_10ms; // 10 ms counter

   always_ff @(posedge clk)
     if(rst)
       count_10ms<='0;
     else if(clk_en)
       count_10ms<='0;
     else
       count_10ms<=count_10ms+18'd1;

   always_comb
     clk_en=(count_10ms==18'd239999);
endmodule
