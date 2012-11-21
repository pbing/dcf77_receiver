/* FPGA Top level */

module CII_Starter_TOP (/* Clock Input */
                        input [1:0]   CLOCK_24,    // 24 MHz
                        input [1:0]   CLOCK_27,    // 27 MHz
                        input         CLOCK_50,    // 50 MHz
                        input         EXT_CLOCK,   // External Clock

                        /* Push Button */
                        input [3:0]   KEY,         // Pushbutton[3:0]

                        /* DPDT Switch */
                        input [9:0]   SW,          // Toggle Switch[9:0]

                        /* 7-SEG Display */
                        output logic [6:0]  HEX0,  // Seven Segment Digit 0
                        output logic [6:0]  HEX1,  // Seven Segment Digit 1
                        output logic [6:0]  HEX2,  // Seven Segment Digit 2
                        output logic [6:0]  HEX3,  // Seven Segment Digit 3

                        /* LED */
                        output logic [7:0]  LEDG,  // LED Green[7:0]
                        output logic [9:0]  LEDR,  // LED Red[9:0]

                        /* UART */
                        output        UART_TXD,    // UART Transmitter
                        input         UART_RXD,    // UART Receiver

                        /* SDRAM Interface */
                        inout  [15:0] DRAM_DQ,     // SDRAM Data bus 16 Bits
                        output [11:0] DRAM_ADDR,   // SDRAM Address bus 12 Bits
                        output        DRAM_LDQM,   // SDRAM Low-byte Data Mask
                        output        DRAM_UDQM,   // SDRAM High-byte Data Mask
                        output        DRAM_WE_N,   // SDRAM Write Enable
                        output        DRAM_CAS_N,  // SDRAM Column Address Strobe
                        output        DRAM_RAS_N,  // SDRAM Row Address Strobe
                        output        DRAM_CS_N,   // SDRAM Chip Select
                        output        DRAM_BA_0,   // SDRAM Bank Address 0
                        output        DRAM_BA_1,   // SDRAM Bank Address 0
                        output        DRAM_CLK,    // SDRAM Clock
                        output        DRAM_CKE,    // SDRAM Clock Enable

                        /* Flash Interface */
                        inout  [7:0]  FL_DQ,       // FLASH Data bus 8 Bits
                        output [21:0] FL_ADDR,     // FLASH Address bus 22 Bits
                        output        FL_WE_N,     // FLASH Write Enable
                        output        FL_RST_N,    // FLASH Reset
                        output        FL_OE_N,     // FLASH Output Enable
                        output        FL_CE_N,     // FLASH Chip Enable

                        /* SRAM Interface */
                        inout  [15:0] SRAM_DQ,     // SRAM Data bus 16 Bits
                        output [17:0] SRAM_ADDR,   // SRAM Address bus 18 Bits
                        output        SRAM_UB_N,   // SRAM High-byte Data Mask
                        output        SRAM_LB_N,   // SRAM Low-byte Data Mask
                        output        SRAM_WE_N,   // SRAM Write Enable
                        output        SRAM_CE_N,   // SRAM Chip Enable
                        output        SRAM_OE_N,   // SRAM Output Enable

                        /* SD Card Interface */
                        inout         SD_DAT,      // SD Card Data
                        inout         SD_DAT3,     // SD Card Data 3
                        inout         SD_CMD,      // SD Card Command Signal
                        output        SD_CLK,      // SD Card Clock

                        /* I2C */
                        inout         I2C_SDAT,    // I2C Data
                        output        I2C_SCLK,    // I2C Clock

                        /* PS2 */
                        input         PS2_DAT,     // PS2 Data
                        input         PS2_CLK,     // PS2 Clock

                        /* USB JTAG link */
                        input         TDI,         // CPLD -> FPGA (data in)
                        input         TCK,         // CPLD -> FPGA (clk)
                        input         TCS,         // CPLD -> FPGA (CS)
                        output        TDO,         // FPGA -> CPLD (data out)

                        /* VGA */
                        output        VGA_HS,      // VGA H_SYNC
                        output        VGA_VS,      // VGA V_SYNC
                        output [3:0]  VGA_R,       // VGA Red[3:0]
                        output [3:0]  VGA_G,       // VGA Green[3:0]
                        output [3:0]  VGA_B,       // VGA Blue[3:0]

                        /* Audio CODEC */
                        inout         AUD_ADCLRCK, // Audio CODEC ADC LR Clock
                        input         AUD_ADCDAT,  // Audio CODEC ADC Data
                        inout         AUD_DACLRCK, // Audio CODEC DAC LR Clock
                        output        AUD_DACDAT,  // Audio CODEC DAC Data
                        inout         AUD_BCLK,    // Audio CODEC Bit-Stream Clock
                        output        AUD_XCK,     // Audio CODEC Chip Clock

                        /* GPIO */
                        inout [35:0]  GPIO_0,      // GPIO Connection 0
                        inout [35:0]  GPIO_1);     // GPIO Connection 1

   import types::*;

   /* common signals */
   wire rst;
   wire clk;

   /* DCF77 receiver and clock */
   wire         clk_en_10ms;
   wire         dcf77_rx;
   wire  [58:0] dcf77_data;
   wire         dcf77_error,dcf77_sync;
   bcd_t [1:0]  year,month,day,hour,minute,second;
   wire  [2:0]  day_of_week;

   /* USB */
   d_port_t   usb_d_i;        // USB port D+,D- (input)
   d_port_t   usb_d_o;        // USB port D+,D- (output)
   logic      usb_d_en;       // USB port D+,D- (enable)
   d_port_t   usb_line_state; // synchronized D+,D-

   wire [7:0] usb_tx_data;    // data from SIE
   wire       usb_tx_valid;   // rise:SYNC,1:send data,fall:EOP
   wire       usb_tx_ready;   // data has been sent

   wire [7:0] usb_rx_data;    // data to SIE
   wire       usb_rx_active;  // active between SYNC und EOP
   wire       usb_rx_valid;   // data valid pulse
   wire       usb_rx_error;   // error detected

   /* synchronize reset */
   logic [0:1] rst_s;
   always_ff @(posedge clk)
     rst_s<={~KEY[0],rst_s[0]};

   /* I/O assignments */
   assign rst       =rst_s[1];
   assign clk       =CLOCK_24[0];

   assign dcf77_rx  =GPIO_1[35];
   assign LEDR[1]   =dcf77_error;
   assign LEDR[0]   =dcf77_rx;

   assign usb_d_i                =d_port_t'({GPIO_1[34],GPIO_1[32]});
   assign {GPIO_1[34],GPIO_1[32]}=(usb_d_en)?usb_d_o:2'bz;

   assign GPIO_1[26]=(rst_s)?1'b0:1'b1;                  // 3.3 V at 1.5 kOhm for USB low-speed detection

   /********************************************************************************
    * DCF77 receiver and clock
    ********************************************************************************/

   wire clock_clk_en     =clk_en_10ms | SW[8]; // SW[8] 0:normal speed, 1:extended speed
   wire clock_dscf77_sync=dcf77_sync  & SW[9]; // SW[9] 0:free running  1:sync with DCF77

   clk_en clk_en(.rst(rst),.clk(clk),.clk_en(clk_en_10ms));

   dcf77 dcf77(.rst(rst),.clk(clk),.clk_en(clk_en_10ms),
	       .rx(dcf77_rx),.data_hold(dcf77_data),
	       .error(dcf77_error),.sync(dcf77_sync));

   clock clock(.rst(rst),.clk(clk),.clk_en(clock_clk_en),
	       .dcf77_sync(clock_dscf77_sync),
	       .dcf77_year(dcf77_data[57:50]),
	       .dcf77_month({3'b0,dcf77_data[49:45]}),
	       .dcf77_day({2'b0,dcf77_data[41:36]}),
	       .dcf77_day_of_week(dcf77_data[44:42]),
	       .dcf77_hour({2'b0,dcf77_data[34:29]}),
	       .dcf77_minute({1'b0,dcf77_data[27:21]}),
	       .year(year),
	       .month(month),
	       .day(day),
	       .day_of_week(day_of_week),
	       .hour(hour),
	       .minute(minute),
	       .second(second));

   /* Switch control for 7-segment display */
   always_comb
     priority case(1'b1)
       SW[0]:
	 begin
	    HEX3=bcd_digit(0);
	    HEX2=bcd_digit(0);
	    HEX1=bcd_digit(second[1]);
	    HEX0=bcd_digit(second[0]);
	 end

       SW[1]:
	 begin
	    {HEX3,HEX2}=week_day_chars(day_of_week);
	    HEX1=bcd_digit(day[1]);
	    HEX0=bcd_digit(day[0]);
	 end

       SW[2]:
	 begin
	    HEX3=bcd_digit(year[1]);
	    HEX2=bcd_digit(year[0]);
	    HEX1=bcd_digit(month[1]);
	    HEX0=bcd_digit(month[0]);
	 end

       default
	 begin
	    HEX3=bcd_digit(hour[1]);
	    HEX2=bcd_digit(hour[0]);
	    HEX1=bcd_digit(minute[1]);
	    HEX0=bcd_digit(minute[0]);
	 end
     endcase

   /********************************************************************************
    * USB Interface
    ********************************************************************************/

   usb_transceiver usb_transceiver (.reset(rst),
				    .clk(clk),
				    .d_i(usb_d_i),.d_o(usb_d_o),.d_en(usb_d_en),.line_state(usb_line_state),
				    .tx_data(usb_tx_data),.tx_valid(usb_tx_valid),.tx_ready(usb_tx_ready),
				    .rx_data(usb_rx_data),.rx_active(usb_rx_active),.rx_valid(usb_rx_valid),.rx_error(usb_rx_error));

   usb_controller usb_controller(.reset(rst),.clk(clk),
				 .line_state(usb_line_state),
				 .tx_data(usb_tx_data),.tx_valid(usb_tx_valid),.tx_ready(usb_tx_ready),
				 .rx_data(usb_rx_data),.rx_active(usb_rx_active),.rx_valid(usb_rx_valid),.rx_error(usb_rx_error));

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
