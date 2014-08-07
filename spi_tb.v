`timescale 1ns / 1ps
module spi_tb;
   parameter clk_per=10;
   parameter sclk_per=10*16.5;
   integer i;
   reg clk=0;
   output reg sclk=0;
   output reg ss=1;
   input  miso;
   output reg mosi;
   initial begin
      $dumpfile("spi_tb.vcd");
      $dumpvars();
      for (i = 0; i < 200; i=i+1) begin

	 $vpi_rw(sclk, mosi, miso, ss);
	 #(sclk_per/2);
              	
      end	
  	      $finish;    
   end
   
      always
        #(clk_per/2) clk = ~clk;

	spi_slave spi_slave (
  		.clk(clk),
  		.rst(rst),
  		.sclk_in(sclk),
  		.ss(ss),      	
  		.mosi(mosi),    
		.rst_led(rst_led),
  		.HDR1_2(HDR1_2),
  		.miso(miso)     
	);

endmodule // tb
