/* Types */

package types;
   typedef enum logic [1:0] {SE0,J,K,SE1} d_port_t; // Low Speed
   //typedef enum logic [1:0] {SE0,K,J,SE1} d_port_t; // Full Speed

   typedef logic [3:0] bcd_t;

   /* packets */
   typedef enum bit [3:0] {/* Token */
			   OUT=4'b001,
			   IN=4'b1001,
			   SOF=4'b0101,
			   SETUP=4'b1101,
			   /* Data */
			   DATA0=4'b0011,
			   DATA1=4'b1011,
			   /* Handshake */
			   ACK=4'b0010,
			   NACK=4'b1010,
			   STALL=4'b1110,
			   /* Special */
			   PRE_ERR=4'b1100
			   } pid_t;
endpackage
