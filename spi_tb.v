`timescale 1ns / 1ps
`include "spi-defines.v"

module spi_tb;


   parameter clk_per=10;
   parameter sclk_per=10*16.5;
   integer i;
   reg clk=0;
   reg rst=1;
   reg sclk=0;
   reg ss=1;
   wire  miso;
   reg mosi;
   reg [`DATA_W-1:0] data_in;
   wire   [`ADDR_W-1:0] address;
   wire   we;

	spi_slave spi_slave (
	       	.clk(clk),
	       	.rst(rst),
	       	.sclk(sclk), 
	       	.ss(ss), 
	       	.mosi(mosi), 
	       	.miso(miso) 
/*	       	.data_in(data_in),
	       	.data_out(data_out),*/
/*		.address(address),
		.we(we)*/
	);

   initial begin
      $dumpfile("spi_tb.vcd");
      $dumpvars();
	#sclk_per
	rst=0;

      for (i = 0; i < 200; i=i+1) begin

	 $vpi_rw(sclk, mosi, miso, ss);
	 #(sclk_per/2);
              	
      end	
  	      $finish;    
   end
   
      always
        #(clk_per/2) clk = ~clk;



endmodule // tb
