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

   localparam       num_endp=2;         // number of endpoints (1...3 for low-speed devices)
   localparam [6:0] usb_device_addr=42; // assigned device address

   import types::*;

   /* common signals */
   wire reset;
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
   logic      usb_reset;      // USB reset due to SE0 for 10 ms

   wire [7:0] usb_tx_data;    // data from SIE
   wire       usb_tx_valid;   // rise:SYNC,1:send data,fall:EOP
   wire       usb_tx_ready;   // DEBUG data has been sent

   wire [7:0] usb_rx_data;    // data to SIE
   wire       usb_rx_active;  // active between SYNC und EOP
   wire       usb_rx_valid;   // data valid pulse
   wire       usb_rx_error;   // error detected

   /* USB Device */
   wire [7:0] usb_endpi_data[num_endp];   // IN endpoint data wire
   wire       usb_endpi_valid[num_endp];  // IN endpoint data valid
   wire       usb_endpi_crc16[num_endp];  // IN endpoint calculate CRC16
   wire       usb_endpi_ready[num_endp];  // IN endpoint data ready

   wire [7:0] usb_endpo_data[num_endp];   // OUT endpoint data output
   wire       usb_endpo_valid[num_endp];  // OUT endpoint data valid
   wire       usb_endpo_crc16[num_endp];  // OUT endpoint CRC16 flag
   wire       usb_endpo_ready[num_endp];  // OUT endpoint data ready

   /* I/O assignments */
   assign clk                    =CLOCK_24[0];
   assign dcf77_rx               =GPIO_1[35];
   assign LEDR[1]                =dcf77_error;
   assign LEDR[0]                =dcf77_rx;
   assign usb_d_i                =d_port_t'({GPIO_1[34],GPIO_1[32]});
   assign {GPIO_1[34],GPIO_1[32]}=(usb_d_en)?usb_d_o:2'bz;
   assign GPIO_1[26]             =(reset)?1'b0:1'b1;

   /********************************************************************************
    * Syncronize reset
    ********************************************************************************/

   sync_reset sync_reset(.key(KEY[0]),.*);

   /********************************************************************************
    * HEX display
    ********************************************************************************/

   display_decoder display_decoder(.SW(SW[2:0]),.*);

   /********************************************************************************
    * DCF77 receiver and clock
    ********************************************************************************/

   wire clock_clk_en      = clk_en_10ms | SW[8];
   wire clock_dscf77_sync = dcf77_sync  & SW[9];

   clk_en clk_en(.reset(reset),.clk(clk),.clk_en(clk_en_10ms));

   dcf77 dcf77(.reset(reset),.clk(clk),.clk_en(clk_en_10ms),
	       .rx(dcf77_rx),.data_hold(dcf77_data),
	       .error(dcf77_error),.sync(dcf77_sync));

   clock clock(.reset(reset),.clk(clk),.clk_en(clock_clk_en),
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

   /********************************************************************************
    * USB Interface
    ********************************************************************************/

   usb_transceiver usb_transceiver (.reset(reset),.clk(clk),
				    .d_i(usb_d_i),.d_o(usb_d_o),.d_en(usb_d_en),.usb_reset(usb_reset),
				    .tx_data(usb_tx_data),.tx_valid(usb_tx_valid),.tx_ready(usb_tx_ready),
				    .rx_data(usb_rx_data),.rx_active(usb_rx_active),.rx_valid(usb_rx_valid),.rx_error(usb_rx_error));

   usb_sie #(num_endp) usb_sie(.reset(usb_reset),.clk(clk),
			       .tx_data(usb_tx_data),.tx_valid(usb_tx_valid),.tx_ready(usb_tx_ready),
			       .rx_data(usb_rx_data),.rx_active(usb_rx_active),.rx_valid(usb_rx_valid),.rx_error(usb_rx_error),
			       .device_addr(usb_device_addr),
			       .endpi_data(usb_endpi_data),.endpi_valid(usb_endpi_data),.endpi_crc16(usb_endpi_data),.endpi_ready(usb_endpi_data),
			       .endpo_data(usb_endpo_data),.endpo_valid(usb_endpo_valid),.endpo_crc16(usb_endpo_crc16),.endpo_ready(usb_endpo_ready));
endmodule
