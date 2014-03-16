/* Interfaces */

interface if_transceiver;
   /* TX */
   logic [7:0] tx_data;   // data from SIE
   logic       tx_valid;  // rise:SYNC,1:send data,fall:EOP
   logic       tx_ready;  // data has been sent

   /* RX */
   logic [7:0] rx_data;   // data to SIE
   logic       rx_active; // active between SYNC und EOP
   logic       rx_valid;  // data valid pulse
   logic       rx_error;  // error detected

   /* control */
   logic       usb_reset; // USB reset due to SE0 for 10 ms
endinterface:if_transceiver

interface if_date_time;
   import types::*;

   logic [13:0] broadcast;   // wheather broadcasts
   logic        r;           // Call bit: abnormal transmitter operation.
   logic        a1;          // Summmer time announcement. Set during hour befor change.
   logic        z1;          // Set to 1 when CEST is in effect.
   logic        z2;          // Set to 1 when CET is in effect.
   logic        a2;          // Leap second annoucement. Set during hour before leap second.
   bcd_t [1:0]  minute;      // minutes
   logic        p1;          // Even parity over minute bits 21–28,
   bcd_t [1:0]  hour;        // hours
   logic        p2;          // Even parity over hour bits 29–35.
   bcd_t [1:0]  day;         // day of month
   logic [2:0]  day_of_week; // day of week
   bcd_t [1:0]  month;       // month number
   bcd_t [1:0]  year;        // year within century
   logic        p3;          // Even parity over date bits 36–58.
   bcd_t [1:0]  second;      // only from clock module
endinterface:if_date_time

interface if_wishbone #(parameter addr_width=4,data_width=8)
   (input                 rst,    // reset
    input                 clk);   // clk

   logic [addr_width-1:0] addr;   // address
   logic [data_width-1:0] data_m; // data from master
   logic [data_width-1:0] data_s; // data from slave
   logic                  cyc;    // cycle
   logic                  stb;    // strobe
   logic                  we;     // write enable
   logic                  ack;    // acknowledge

   modport master(input rst,clk,output addr,data_m,cyc,stb,we,input  data_s,ack);
   modport slave (input rst,clk,input  addr,data_m,cyc,stb,we,output data_s,ack);
endinterface:if_wishbone

interface if_fifo #(parameter addr_width=4,data_width=8)
   (input                 clock); // clock

   logic [data_width-1:0] data;   // input data
   logic [data_width-1:0] q;      // output data
   logic [addr_width-1:0] usedw;  // used words
   logic                  sclr;   // synchronous clear (flush FIFO)
   logic                  rdreq;  // read request
   logic                  wrreq;  // write request
   logic                  empty;  // FIFO empty
   logic                  full;   // FIFO full
endinterface:if_fifo

interface if_io;
   logic [15:0] din;  // io data in
   logic        rd;   // io read
   logic        wr;   // io write
   logic [15:0] addr; // io address
   logic [15:0] dout; // io data out
endinterface:if_io
