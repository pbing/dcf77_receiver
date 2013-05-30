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
endinterface

interface if_endpoint #(parameter n=1);
   logic [7:0] data[n];
   logic       valid[n];
   logic       crc16[n];
   logic       ready[n];
endinterface

interface if_date_time;
   import types::*;
   
   bcd_t [1:0]  year;
   bcd_t [1:0]  month;
   bcd_t [1:0]  day;
   bcd_t [1:0]  hour;
   bcd_t [1:0]  minute;
   bcd_t [1:0]  second;
   logic [2:0]  day_of_week;
endinterface
