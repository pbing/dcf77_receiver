/* Testbench top-level */

module tb_top;
   timeunit 1ns;
   timeprecision 1ps;

   const realtime tclk24=1s/24e6;


   bit	[1:0]	CLOCK_24;				//	24 MHz
   bit	[1:0]	CLOCK_27;				//	27 MHz
   bit			CLOCK_50;				//	50 MHz
   bit			EXT_CLOCK;				//	External Clock
   ////////////////////////	Push Button		////////////////////////
   bit	[3:0]	KEY;					//	Pushbutton[3:0]
   ////////////////////////	DPDT Switch		////////////////////////
   bit	[9:0]	SW;						//	Toggle Switch[9:0]
   ////////////////////////	7-SEG Dispaly	////////////////////////
   wire	[6:0]	HEX0;					//	Seven Segment Digit 0
   wire	[6:0]	HEX1;					//	Seven Segment Digit 1
   wire	[6:0]	HEX2;					//	Seven Segment Digit 2
   wire	[6:0]	HEX3;					//	Seven Segment Digit 3
   ////////////////////////////	LED		////////////////////////////
   wire	[7:0]	LEDG;					//	LED Green[7:0]
   wire	[9:0]	LEDR;					//	LED Red[9:0]
   ////////////////////////////	UART	////////////////////////////
   wire			UART_TXD;				//	UART Transmitter
   bit			UART_RXD;				//	UART Receiver
   ///////////////////////		SDRAM Interface	////////////////////////
   wire	[15:0]	DRAM_DQ;				//	SDRAM Data bus 16 Bits
   wire	[11:0]	DRAM_ADDR;				//	SDRAM Address bus 12 Bits
   wire			DRAM_LDQM;				//	SDRAM Low-byte Data Mask
   wire			DRAM_UDQM;				//	SDRAM High-byte Data Mask
   wire			DRAM_WE_N;				//	SDRAM Write Enable
   wire			DRAM_CAS_N;				//	SDRAM Column Address Strobe
   wire			DRAM_RAS_N;				//	SDRAM Row Address Strobe
   wire			DRAM_CS_N;				//	SDRAM Chip Select
   wire			DRAM_BA_0;				//	SDRAM Bank Address 0
   wire			DRAM_BA_1;				//	SDRAM Bank Address 0
   wire			DRAM_CLK;				//	SDRAM Clock
   wire			DRAM_CKE;				//	SDRAM Clock Enable
   ////////////////////////	Flash Interface	////////////////////////
   wire	[7:0]	FL_DQ;					//	FLASH Data bus 8 Bits
   wire	[21:0]	FL_ADDR;				//	FLASH Address bus 22 Bits
   wire			FL_WE_N;				//	FLASH Write Enable
   wire			FL_RST_N;				//	FLASH Reset
   wire			FL_OE_N;				//	FLASH Wire Enable
   wire			FL_CE_N;				//	FLASH Chip Enable
   ////////////////////////	SRAM Interface	////////////////////////
   wire	[15:0]	SRAM_DQ;				//	SRAM Data bus 16 Bits
   wire	[17:0]	SRAM_ADDR;				//	SRAM Address bus 18 Bits
   wire			SRAM_UB_N;				//	SRAM High-byte Data Mask
   wire			SRAM_LB_N;				//	SRAM Low-byte Data Mask
   wire			SRAM_WE_N;				//	SRAM Write Enable
   wire			SRAM_CE_N;				//	SRAM Chip Enable
   wire			SRAM_OE_N;				//	SRAM Wire Enable
   ////////////////////	SD Card Interface	////////////////////////
   wire			SD_DAT;					//	SD Card Data
   wire			SD_DAT3;				//	SD Card Data 3
   wire			SD_CMD;					//	SD Card Command Signal
   wire			SD_CLK;					//	SD Card Clock
   ////////////////////////	I2C		////////////////////////////////
   wire			I2C_SDAT;				//	I2C Data
   wire			I2C_SCLK;				//	I2C Clock
   ////////////////////////	PS2		////////////////////////////////
   bit		 	PS2_DAT;				//	PS2 Data
   bit			PS2_CLK;				//	PS2 Clock
   ////////////////////	USB JTAG link	////////////////////////////
   bit  			TDI;					// CPLD -> FPGA (data in)
   bit  			TCK;					// CPLD -> FPGA (clk)
   bit  			TCS;					// CPLD -> FPGA (CS)
   wire 			TDO;					// FPGA -> CPLD (data out)
   ////////////////////////	VGA			////////////////////////////
   wire			VGA_HS;					//	VGA H_SYNC
   wire			VGA_VS;					//	VGA V_SYNC
   wire	[3:0]	VGA_R;   				//	VGA Red[3:0]
   wire	[3:0]	VGA_G;	 				//	VGA Green[3:0]
   wire	[3:0]	VGA_B;   				//	VGA Blue[3:0]
   ////////////////////	Audio CODEC		////////////////////////////
   wire			AUD_ADCLRCK;			//	Audio CODEC ADC LR Clock
   bit			AUD_ADCDAT;				//	Audio CODEC ADC Data
   wire			AUD_DACLRCK;			//	Audio CODEC DAC LR Clock
   wire			AUD_DACDAT;				//	Audio CODEC DAC Data
   wire			AUD_BCLK;				//	Audio CODEC Bit-Stream Clock
   wire			AUD_XCK;				//	Audio CODEC Chip Clock
   ////////////////////////	GPIO	////////////////////////////////
   wire	[35:0]	GPIO_0;					//	GPIO Connection 0
   wire	[35:0]	GPIO_1;					//	GPIO Connection 1

   bit rx;

   CII_Starter_TOP dut(.*);

   assign GPIO_1[35]=rx;

   initial forever #(tclk24/2) CLOCK_24=~CLOCK_24;

   initial
     begin
	#1us KEY[0]=1;

	#1ms fork
	   repeat(3) send_dcf77();
	join_none

	#125s $stop;
     end

   task send_bit(input x);
      rx=1;

      if(x)
	begin
	   #200ms rx=0;
	   #800ms;
	   //#50ms; // #800ms simulation speed-up
	end
      else
	begin
	   #100ms rx=0;
	   #900ms;
	   //#50ms; // #900ms simulation speed-up
	end
   endtask

   task send_dcf77(int start=0);
      logic [59:0] data;
      data=new_dcf77_data();

      // TODO
      //      if(start>0)
      //	begin
      //	   force tb_top.CII_Starter_TOP.dcf77.data_shift=data;
      //	   #10ms release tb_top.CII_Starter_TOP.dcf77.data_shift;
      //	end

      for(int i=0;i<60;i++)
	if(data[i]===1'bz)
	  #1s;
	else
	  send_bit(data[i]);
   endtask

   function [59:0] new_dcf77_data();
      new_dcf77_data[0]=1'b0; // start new minute

      new_dcf77_data[19:1]=$random;

      new_dcf77_data[20]=1'b1; // start time information

      /* minutes */
      new_dcf77_data[24:21]={$random}%10;
      new_dcf77_data[27:25]={$random}%6;
      new_dcf77_data[28]=^new_dcf77_data[27:21];

      /* hours */
      new_dcf77_data[32:29]={$random}%10;
      new_dcf77_data[34:33]={$random}%3;
      if(new_dcf77_data[34:33]==2'd2 && new_dcf77_data[32:29]>4'd3)
	begin
	   new_dcf77_data[32:29]-=4;
	   new_dcf77_data[34:33]=0;
	end
      new_dcf77_data[35]=^new_dcf77_data[34:29];

      /* day of month */
      new_dcf77_data[39:36]={$random}%10;
      new_dcf77_data[41:40]=$random;
      if(new_dcf77_data[41:40]==2'd3 && new_dcf77_data[39:36]>4'd1)
	new_dcf77_data[41:40]=0;

      /* day of week */
      new_dcf77_data[44:42]={$random}%7+1;

      /* month */
      new_dcf77_data[48:45]={$random}%10;
      new_dcf77_data[49]=$random;
      if(new_dcf77_data[49]==1'b1 && new_dcf77_data[48:45]>4'd2)
	new_dcf77_data[49]-=1;

      /* year */
      new_dcf77_data[53:50]={$random}%10;
      new_dcf77_data[57:54]={$random}%10;

      new_dcf77_data[58]=^new_dcf77_data[57:36];

      new_dcf77_data[59]=1'bz;
   endfunction
endmodule
