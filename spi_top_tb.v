`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   16:57:57 09/02/2014
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

module spi_top_tb;

	// Inputs
	reg mosi;
	reg ss;
	reg sclk;
	reg clk;
	reg rst;

	// Outputs
	wire miso;
	wire rst_led;

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
		// Initialize Inputs
		mosi = 0;
		ss = 0;
		sclk = 0;
		clk = 0;
		rst = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here

	end
      
endmodule

