/* Types */

package types;
   /* Symbols J and K have inverse polarity in each USB mode */
   typedef enum logic [1:0] {SE0,J,K,SE1} d_port_t; // Low Speed (1.5 MHz)
   //typedef enum logic [1:0] {SE0,K,J,SE1} d_port_t; // Full Speed (12 MHz)

   /* BCD encoding */
   typedef logic [3:0] bcd_t;

   /* Packets */
   typedef enum bit [3:0] {/* Token */
			   OUT    =4'b0001,
			   IN     =4'b1001,
			   SOF    =4'b0101,
			   SETUP  =4'b1101,
			   /* Data */
			   DATA0  =4'b0011,
			   DATA1  =4'b1011,
			   /* Handshake */
			   ACK    =4'b0010,
			   NAK    =4'b1010,
			   STALL  =4'b1110,
			   /* Special */
			   PRE_ERR=4'b1100
			   } pid_t;
endpackage
