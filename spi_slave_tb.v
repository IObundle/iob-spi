
`timescale 1ns / 1ps
`include "rcntlr_defines.v"

module spi_slave_tb ();
   reg clk;
   reg rst;
   reg sclk;
   reg ss;
   reg mosi;
   wire miso;


   reg [7:0] data;
   reg [15:0] data_out;
   reg [6:0]  addr;
   reg 	      wr;
   
   integer    i;
   
   
   
   parameter clk_per= (10**9)/(16*10**6);
   parameter sclk_per= 16.5*(10**9)/(16*10**6);
   
   

   spi_slave dut(
		 .clk (clk),
		 .rst (rst),
		 .sclk (sclk),
		 .ss (ss),
		 .mosi (mosi),
		 .miso (miso)
		 );
   
   initial begin
      $dumpfile("spi_slave.vcd");
      $dumpvars(0,dut);
      rst = 1;
      clk = 1;
      sclk = 0;
      i = 15;
      ss = 1;
      
      addr = 7'b1010101;
      data = 8'hFA;
      wr = 1'b0;      
      data_out = {wr,addr,data};
      mosi <= data_out[15];  
            
      #(sclk_per*1.5 + 1) rst = 0;
		ss = 0;

      /*FIRST WORD WRITE*/ 
      for (i=14;i>=0;i=i-1) begin
	 #(sclk_per) mosi <= data_out[i];
      end
      /*SECOND WORD WRITE*/
      addr = 7'b0101010;
      data = 8'h2F;
      wr = 1'b0;      
      data_out = {wr,addr,data};
      #(sclk_per)
      mosi <= data_out[15];   
      for (i=14;i>=0;i=i-1) begin
	 #(sclk_per) mosi <= data_out[i];
      end

      /*FIRST WORD READ*/
      addr = 7'b1010101;
      data = 8'h00;
      wr = 1'b1;
      data_out = {wr,addr,data};
      #(sclk_per)
      mosi <= data_out[15];   
      for (i=14;i>=0;i=i-1) begin
	 #(sclk_per) mosi <= data_out[i];
      end


      /*THIRD WORD WRITE*/
      addr = 7'b1101011;
      data = 8'hAA;
      wr = 1'b0;      
      data_out = {wr,addr,data};
      #(sclk_per)
      mosi <= data_out[15];   
      for (i=14;i>=0;i=i-1) begin
	 #(sclk_per) mosi <= data_out[i];
      end
      
      /*SECOND WORD READ*/
      addr = 7'b0101010;
      data = 8'h00;
      wr = 1'b1;
      data_out = {wr,addr,data};
      #(sclk_per)
      mosi <= data_out[15];   
      for (i=14;i>=0;i=i-1) begin
	 #(sclk_per) mosi <= data_out[i];
      end
      
      #(sclk_per*50) ss <= 1'b1;
         
      
      #(clk_per) $finish;
 
	
   end
   
   always
     #(clk_per/2) clk = ~clk;
   always
     #(sclk_per/2) sclk = ~sclk;
   

endmodule
