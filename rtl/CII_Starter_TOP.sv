/* FPGA Top level
 *
 * KEY[0]       external reset
 *
 * SW[0]        display seconds
 * SW[1]        display week day and day of month month
 * SW[2]        display year and month
 * SW[8]        0:normal speed   1:extended speed
 * SW[9]        0:free running   1:sync with DCF77
 *
 * LEDR[1]      DCF77 ERROR
 * LEDR[0]      DCF77 RX pulse
 *
 * GPIO_1[26]   3.3 V at 1.5 kOhm for USB low-speed detection. Low during external reset for starting new communication.
 * GPIO_1[32]   USB-D+
 * GPIO_1[34]   USB-D-≈
 * GPIO_1[35]   DCF77 RX pulse
 *
 *
 *
 * USB Registers
 * ---------------------------------------------------------------------------------------------------
 * 0   usb_device_controller   rw
 * 1   dcf77_data[63:0]        r
 * 2   display[47:0]           w    {2'b0,LEDR[9:0],LEDG[7:0],HEX3[6:0],HEX2[6:0],HEX1[6:0],HEX0[6:0]}
 */

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
   wire reset;
   wire clk;

   /* DCF77 receiver and clock */
   wire  clk_en_10ms;
   wire  dcf77_rx;
   wire  dcf77_error;
   wire  dcf77_sync;
   logic clock_clk_en;
   logic clock_dscf77_sync;

   /* USB */
   d_port_t   usb_d_i;        // USB port D+,D- (input)
   d_port_t   usb_d_o;        // USB port D+,D- (output)
   wire       usb_d_en;       // USB port D+,D- (enable)
   wire       usb_reset;      // USB reset due to SE0 for 10 ms

   /* I/O assignments */
   assign clk                    =CLOCK_24[0];
   assign dcf77_rx               =GPIO_1[35];
   assign LEDR[1]                =dcf77_error;
   assign LEDR[0]                =dcf77_rx;
   assign usb_d_i                =d_port_t'({GPIO_1[34],GPIO_1[32]});
   assign {GPIO_1[34],GPIO_1[32]}=(usb_d_en)?usb_d_o:2'bz;
   assign GPIO_1[26]             =(reset)?1'b0:1'b1;

   /********************************************************************************
    * DCF77 receiver and clock
    ********************************************************************************/

   if_date_time dcf77_date_time();
   if_date_time clock_date_time();

   sync_reset sync_reset(.clk(clk),.key(KEY[0]),.reset(reset));

   clk_en clk_en(.reset(reset),.clk(clk),.clk_en(clk_en_10ms));

   dcf77 dcf77(.reset(reset),.clk(clk),.clk_en(clk_en_10ms),
	       .rx(dcf77_rx),
	       .data_hold(/*open*/),
	       .error(dcf77_error),.sync(dcf77_sync),
	       .date_time(dcf77_date_time));

   clock clock(.reset(reset),.clk(clk),.clk_en(clock_clk_en),
	       .dcf77_sync(clock_dscf77_sync),
	       .dcf77(dcf77_date_time),
	       .clock(clock_date_time));

   display_decoder display_decoder(.SW(SW[2:0]),
				   .clock(clock_date_time),
				   .HEX0(HEX0),.HEX1(HEX1),.HEX2(HEX2),.HEX3(HEX3));

   /* control with on-board switches */
   always_comb
     begin
	clock_clk_en      = clk_en_10ms | SW[8];
	clock_dscf77_sync = dcf77_sync  & SW[9];
     end

   /********************************************************************************
    * USB Interface
    ********************************************************************************/

   if_transceiver transceiver();
   if_wishbone    wbm   (.rst(usb_reset),.clk(clk));
   if_wishbone    wbs[2](.rst(usb_reset),.clk(clk));

   usb_transceiver usb_transceiver (.reset(reset),.clk(clk),
				    .d_i(usb_d_i),.d_o(usb_d_o),.d_en(usb_d_en),.usb_reset(usb_reset),
				    .transceiver(transceiver));

   wb_shared_bus wb_shared_bus(.wbm(wbm),.wbs(wbs));

   usb_sie usb_sie(.wb(wbm),.transceiver(transceiver));
   
   /* USB device[0] */
   usb_device_controller #(.addr(0)) usb_device_controller(.wb(wbs[0]));

   /* USB device[1] */
   dcf77_registers dcf77_registers(.wb(wbs[1]),.dcf77_date_time(dcf77_date_time),.clock_date_time(clock_date_time));

   /* USB device[2] */
   //display_register #(.addr(2)) (.wbs[2],...);
endmodule
