
`timescale 1ns / 1ps
`include "rcntlr_defines.v"
////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   11:20:07 09/03/2014
// Design Name:   spi_top
// Module Name:   C:/Dokandre/School_Stuff/Estagio_INESC/spi/spi_top_tb.v
// Project Name:  SPI_Slave
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: spi_top
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module spi_top_tb();

	// Inputs
	reg mosi;
	reg ss;
	reg sclk;
	reg clk;
	reg rst;

	// Outputs
	wire miso;
	wire rst_led;
	

	
   reg [`DATA_WIDTH-1:0] data;
   reg [`LOG_N_REGISTERS+`DATA_WIDTH-1:0] data_out;
   reg [`LOG_N_REGISTERS-1:0]  addr;
   reg 	      wr;
   
   integer    i;
   
   
   
   parameter clk_per= (10**9)/(16*10**6);
   parameter sclk_per= 16.5*(10**9)/(16*10**6);
		// Instantiate the Unit Under Test (UUT)
	spi_top uut (
		.mosi(mosi), 
		.ss(ss), 
		.sclk(sclk), 
		.clk(clk), 
		.rst(rst), 
		.miso(miso), 
		.rst_led(rst_led)
	);

   initial begin
      $dumpfile("spi_top.vcd");
      $dumpvars();
      rst = 1;
      clk = 1;
      sclk = 0;
      i = 15;
      ss = 1;
      
      addr = 4'b0101;
      data = 32'hFAFAFAFA;
      wr = 1'b0;      
      mosi <= wr;  
            
      #(sclk_per*1.5 + 1) rst = 0;
		ss = 0;

      /*FIRST WORD WRITE*/ 
      for (i=`LOG_N_REGISTERS-1;i>=0;i=i-1) begin
	 #(sclk_per) mosi <= addr[i];
      end
	 #(sclk_per) ss = 1;
	 #(2*sclk_per) ss = 0;
		mosi <= data[`DATA_WIDTH-1];
		for(i=`DATA_WIDTH-2;i>=0; i=i-1) begin
			#(sclk_per) mosi <= data[i];
		end
	 #(sclk_per) ss = 1;
	 
	 
      /*SECOND WORD WRITE*/
      addr = 4'b1010;
      data = 32'h2F2F2F2F;
      wr = 1'b0;      
      #(sclk_per)
      mosi <= wr;
		ss = 0;
      for (i=`LOG_N_REGISTERS-1;i>=0;i=i-1) begin
	 #(sclk_per) mosi <= addr[i];
      end
	 #(sclk_per) ss = 1;
	 #(2*sclk_per) ss = 0;
		mosi <= data[`DATA_WIDTH-1];
		for(i=`DATA_WIDTH-2;i>=0; i=i-1) begin
			#(sclk_per) mosi <= data[i];
		end
	 #(sclk_per) ss = 1;

      /*FIRST WORD READ*/
      addr = 4'b0101;
      data = 32'h00000000;
      wr = 1'b1;
      #(sclk_per)
      mosi <= wr;
		ss = 0;
      for (i=`LOG_N_REGISTERS-1;i>=0;i=i-1) begin
	 #(sclk_per) mosi <= addr[i];
      end
	 #(sclk_per) ss = 1;
	 #(2*sclk_per) ss = 0;
		mosi <= data[`DATA_WIDTH-1];
		for(i=`DATA_WIDTH-2;i>=0; i=i-1) begin
			#(sclk_per) mosi <= data[i];
		end
	 #(sclk_per) ss = 1;


      /*THIRD WORD WRITE*/
      addr = 4'b1011;
      data = 32'hAAAAAAAA;
      wr = 1'b0;      
      #(sclk_per)
      mosi <= wr;
		ss = 0;
      for (i=`LOG_N_REGISTERS-1;i>=0;i=i-1) begin
	 #(sclk_per) mosi <= addr[i];
      end
	 #(sclk_per) ss = 1;
	 #(2*sclk_per) ss = 0;
		mosi <= data[`DATA_WIDTH-1];
		for(i=`DATA_WIDTH-2;i>=0; i=i-1) begin
			#(sclk_per) mosi <= data[i];
		end
	 #(sclk_per) ss = 1;
      
      /*SECOND WORD READ*/
      addr = 4'b1010;
      data = 32'h00000000;
      wr = 1'b1;
      #(sclk_per)
      mosi <= wr;
		ss = 0;
      for (i=`LOG_N_REGISTERS-1;i>=0;i=i-1) begin
	 #(sclk_per) mosi <= addr[i];
      end
	 #(sclk_per) ss = 1;
	 #(2*sclk_per) ss = 0;
		mosi <= data[`DATA_WIDTH-1];
		for(i=`DATA_WIDTH-2;i>=0; i=i-1) begin
			#(sclk_per) mosi <= data[i];
		end
	 #(sclk_per) ss = 1;
	 
	 
      #(clk_per) $finish;
 
	
   end
   
   always
     #(clk_per/2) clk = ~clk;
   always
     #(sclk_per/2) sclk = ~sclk;
   

endmodule

