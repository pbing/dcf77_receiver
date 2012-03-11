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
                        output [6:0]  HEX0,        // Seven Segment Digit 0
                        output [6:0]  HEX1,        // Seven Segment Digit 1
                        output [6:0]  HEX2,        // Seven Segment Digit 2
                        output [6:0]  HEX3,        // Seven Segment Digit 3

                        /* LED */
                        output [7:0]  LEDG,        // LED Green[7:0]
                        output [9:0]  LEDR,        // LED Red[9:0]

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

   //   Turn off all display
   //   assign  HEX0            =       '1;
   //   assign  HEX1            =       '1;
   //   assign  HEX2            =       '1;
   //   assign  HEX3            =       '1;
   //   assign  LEDG            =       8'hFF;
   //   assign  LEDR            =       10'h3FF;

   //   All inout port turn to tri-state
   assign       DRAM_DQ         =       16'hzzzz;
   assign       FL_DQ           =       8'hzz;
   assign       SRAM_DQ         =       16'hzzzz;
   assign       SD_DAT          =       1'bz;
   assign       I2C_SDAT        =       1'bz;
   assign       AUD_ADCLRCK     =       1'bz;
   assign       AUD_DACLRCK     =       1'bz;
   assign       AUD_BCLK        =       1'bz;
   assign       GPIO_0          =       36'hzzzzzzzzz;
   assign       GPIO_1          =       36'hzzzzzzzzz;

   wire        rst; 
   wire        clk;
   wire        rx; 
   wire [58:0] data_hold;
   wire        error;

   /* synchronize reset */
   logic [0:1] rst_s;
   always_ff @(posedge clk)
     rst_s<={~KEY[0],rst_s[0]};
   
   assign rst=rst_s[1];
   assign clk=CLOCK_24[0];
   
   assign rx=GPIO_1[35];

   /* DEBUG */
   assign LEDG[3:0]=data_hold[24:21]; // MM Einer
   assign LEDG[7:4]=data_hold[28:25]; // MM Zehner

   assign LEDR[3:0]=data_hold[32:29]; // HH Einer
   assign LEDR[6:4]=data_hold[35:33]; // HH Zehner
   assign LEDR[9:7]=data_hold[44:42]; // WW

   //   assign LEDR[3:0]=data_hold[53:50]; // YY Einer
   //   assign LEDR[7:4]=data_hold[57:54]; // YY Zehner
   //   assign LEDR[8]=data_hold[58];      // YY parity

   assign HEX3='1;
   assign HEX2=(error)?~7'b1111001:~7'b1000000;
   assign HEX1=(error)?~7'b1010000:~7'b1000000;
   assign HEX0=(error)?~7'b1010000:~7'b1000000;

   dcf77 dcf77(.rst(rst),.clk(clk),.rx(rx),.data_hold(data_hold),.error(error));

endmodule
