
`timescale 1ns / 1ps
`include "spi_defines.v"

module spi_master_tb;

   reg 		rst;
   reg 		clk;
   
   //spi master inputs 
   reg 		sclk;
   reg 		start;

   reg [`SPI_ADDR_W-1:0]  address;
   reg [`SPI_DATA_W-1:0] data_in;
   reg 			 rnw;

   wire 		miso;
   
   
   //spi master outputs 
   wire [`SPI_DATA_W-1:0] data_out;
   wire			ready;	

   wire 		mosi;
   wire 		ss;
	
   
   //spi slave outputs 
   wire [`SPI_ADDR_W-1:0] address_s;		
   wire 		  we_s;			
   wire [`SPI_DATA_W-1:0] data_out_s;

   wire [`SPI_DATA_W-1:0] data_in_s; //from register bank

    
   parameter sclk_per= 200;
   parameter clk_per= 20;
   
   // Instantiate the Unit Under Test (UUT)
   spi_master uut (/*AUTOINST*/
		   // Outputs
		   .ss			(ss),
		   .mosi		(mosi),
		   .data_out		(data_out[`SPI_DATA_W-1:0]),
		   .ready		(ready),
		   // Inputs
		   .rst			(rst),
		   .sclk		(sclk),
		   .miso		(miso),
		   .data_in		(data_in[`SPI_DATA_W-1:0]),
		   .address		(address[`SPI_ADDR_W-1:0]),
		   .rnw		(rnw),
		   .start		(start));
   
   spi_slave spi_s (/*AUTOINST*/
		    // Outputs
		    .miso		(miso),
		    .data_out		(data_out_s[`SPI_DATA_W-1:0]),
		    .address		(address_s[`SPI_ADDR_W-1:0]),
		    .we			(we_s),
		    // Inputs
		    .clk		(clk),
		    .rst		(rst),
		    .sclk		(sclk),
		    .ss			(ss),
		    .mosi		(mosi),
		    .data_in		(data_in_s[`SPI_DATA_W-1:0]));


   register_bank rb (/*AUTOINST*/
		     // Outputs
		     .data_out		(data_in_s[`SPI_DATA_W-1:0]),
		     // Inputs
		     .clk		(clk),
		     .rst		(rst),
		     .wr		(we_s),
		     .address		(address_s[`SPI_ADDR_W-1:0]),
		     .data_in		(data_out_s[`SPI_DATA_W-1:0]));
   
   initial begin
      $dumpfile("spi_master.vcd");
      $dumpvars();
      rst = 1;
      clk = 1;
      
      sclk = 1;
      start = 0;
      
      
      address = 4'b0101;
      data_in = 32'hF0F0F0F0;
      rnw = 1'b0;      	 

      #201 rst = 0;

      #200 start = 1;
      
      #200 start = 0;
      
      #10000 start = 1;
      rnw = 1;

      #200 start = 0;
      
      
      #10000
      $finish;

   end
   

   always
     #(sclk_per/2) sclk = ~sclk;
   
   always
     #(clk_per/2) clk = ~clk;
   

endmodule

