/* Testbench USB Serial Interface Controller */

module tb_usb_sie;
   timeunit 1ns;
   timeprecision 1ps;

   const realtime tusb=1s/1.5e6,       // low speed
		  tclk=1s/24.0e6,
		  nbit=tusb/tclk;

   import types::*;

   bit        reset=1'b1;            // system reset
   bit        clk;                   // system clock (24 MHz)

   byte GET_DESCRIPTOR[]='{8'h80,8'h06,8'h00,8'h01,8'h00,8'h00,8'h08,8'h00};

   if_transceiver transceiver();
   if_wishbone    wb(.rst(reset),.clk(clk));

   usb_sie dut(.*);

   initial forever #(tclk/2) clk=~clk;

   /* synchronous slave */
   always @(posedge wb.clk)
     begin:slave
	if(wb.rst)
	  wb.ack<=1'b0;
	else
	  if(wb.ack)
	    wb.ack<=1'b0;
	  else if(wb.cyc && wb.stb)
	    wb.ack<=1'b1;
     end:slave

   initial
     begin:main
	$timeformat(-9,15," ns");

	/* Some tests according to http://www.usb.org/developers/whitepapers/crcdes.pdf */
	assert(crc5({4'he,7'h15})==5'b11101) else $error("CRC5");;
	assert(crc5({4'ha,7'h3a})==5'b00111) else $error("CRC5");;
	assert(crc5({4'h4,7'h70})==5'b01110) else $error("CRC5");;

	assert(crc16('{8'h00,8'h01,8'h02,8'h03})==16'h7aef) else $error("CRC16");
	assert(crc16('{8'h23,8'h45,8'h67,8'h89})==16'h1c0e) else $error("CRC16");
	assert(crc16()                          ==16'h0000) else $error("CRC16"); // zero length packet

	/* initial interface state */
	transceiver.rx_active=1'b0;
	transceiver.rx_valid =1'b0;
	transceiver.rx_error =1'b0;
	transceiver.tx_ready =1'b0;

	repeat(3) @(posedge clk);
	reset=1'b0;
	#100ns;

	/**********************************************************************
	 * Control Read
	 **********************************************************************/

	/* Setup Stage */
	receive_token(SETUP,0,0);
	receive_data(DATA0,GET_DESCRIPTOR);
	#30us; //send_handshake(ACK);

	/* -----\/----- EXCLUDED -----\/-----
	 /-* Data Stage *-/
	 #10us receive_token(IN,0,0);
	 //send_data(...);
	 receive_handshake(ACK);
	 #5us @(posedge clk) reset=1'b1;@(posedge clk) reset=1'b0; // reset FSM
	 -----/\----- EXCLUDED -----/\----- */

	/* Status Stage */
	#10us receive_token(OUT,0,0);
	receive_data(DATA0); // ZLP
	#30us $stop; //send_handshake(ACK);

	#10us $finish;
     end:main

   always @(posedge transceiver.tx_valid)
     begin:tx
	/* SYNC */
	repeat(7*nbit+1) @(posedge clk);

	fork
	   wait(!transceiver.tx_valid);

	   begin
	      repeat(8*nbit-1) @(posedge clk);
	      transceiver.tx_ready<=1'b1;
	      @(posedge clk) transceiver.tx_ready<=1'b0;
	   end
	join_any
     end:tx

   task send_handshake(input pid_t pid);
      do @(posedge clk); while(!transceiver.tx_valid);

      assert(transceiver.tx_data=={~pid,pid});

      do @(posedge clk); while(transceiver.tx_valid);
   endtask

   task receive_token(input pid_t pid,input [6:0] addr,input [3:0] endp);
      repeat(2) @(posedge clk);
      wait(!transceiver.tx_valid);

      /* PID */
      repeat(8*nbit-1) @(posedge clk);
      transceiver.rx_active<=1'b1;
      transceiver.rx_valid<=1'b1;
      transceiver.rx_data <={~pid,pid};
      @(posedge clk) transceiver.rx_valid<=1'b0;

      /* ADDR and first bit of ENDP */
      repeat(8*nbit-1) @(posedge clk);
      transceiver.rx_valid<=1'b1;
      transceiver.rx_data <={endp[0],addr};
      @(posedge clk) transceiver.rx_valid<=1'b0;

      /* Rest of ENDP and CRC5 */
      repeat(8*nbit-1) @(posedge clk);
      transceiver.rx_valid<=1'b1;
      transceiver.rx_data <={crc5({endp,addr}),endp[3:1]};
      @(posedge clk) transceiver.rx_valid<=1'b0;

      /* EOP */
      repeat(2*nbit) @(posedge clk);
      transceiver.rx_active<=1'b0;
      @(posedge clk);
   endtask

   task receive_data(input pid_t pid,input byte data[]='{});
      /* PID */
      repeat(8*nbit-1) @(posedge clk);
      transceiver.rx_active<=1'b1;
      transceiver.rx_valid<=1'b1;
      transceiver.rx_data <={~pid,pid};
      @(posedge clk) transceiver.rx_valid<=1'b0;

      foreach(data[i])
	begin
	   repeat(8*nbit-1) @(posedge clk);
	   transceiver.rx_valid<=1'b1;
	   transceiver.rx_data <=data[i];
	   @(posedge clk) transceiver.rx_valid<=1'b0;
	end

      /* CRC16 */
      for(int i=0;i<16;i+=8)
	begin
	   repeat(8*nbit-1) @(posedge clk);
	   transceiver.rx_valid<=1'b1;
	   transceiver.rx_data <=crc16(data)[7+i-:8];
	   @(posedge clk) transceiver.rx_valid<=1'b0;
	end

      /* EOP */
      repeat(2*nbit) @(posedge clk);
      transceiver.rx_active<=1'b0;
      @(posedge clk);
   endtask

   task receive_random_data(input pid_t pid, input int n);
      byte data[];

      data=new[n];
      for(int i=0;i<n;i++) data[i]=$random;
      receive_data(pid,data);
   endtask

   task receive_handshake(input pid_t pid);
      /* PID */
      repeat(8*nbit-1) @(posedge clk);
      transceiver.rx_active<=1'b1;
      transceiver.rx_valid<=1'b1;
      transceiver.rx_data <={~pid,pid};
      @(posedge clk) transceiver.rx_valid<=1'b0;

      /* EOP */
      repeat(2*nbit) @(posedge clk);
      transceiver.rx_active<=1'b0;
      @(posedge clk);
   endtask

   function [4:0] crc5(input [10:0] d);
      const bit [4:0] crc5_poly=5'b10100,
		      crc5_res =5'b00110;

      crc5='1;

      for(int i=$right(d);i<=$left(d);i++)
	if(crc5[$right(crc5)]^d[i])
	  crc5=(crc5>>1)^crc5_poly;
	else
	  crc5=crc5>>1;

      crc5=~crc5;
   endfunction

   function [15:0] crc16(input byte d[]='{});
      const bit [15:0] crc16_poly=16'b1010000000000001,
		       crc16_res =16'b1011000000000001;

      crc16='1;

      foreach(d[j])
	for(int i=$right(d[j]);i<=$left(d[j]);i++)
	  if(crc16[$right(crc16)]^d[j][i])
	    crc16=(crc16>>1)^crc16_poly;
	  else
	    crc16=crc16>>1;

      crc16=~crc16;
   endfunction
endmodule
