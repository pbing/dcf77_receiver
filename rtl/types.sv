/* Types */

package types;
   typedef enum logic[1:0] {SE0,J,K,SE1} d_port_t; // Low Speed
   //typedef enum logic[1:0] {SE0,K,J,SE1} d_port_t; // Full Speed

   typedef logic [3:0] bcd_t;
endpackage
