`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:48:07 09/02/2014 
// Design Name: 
// Module Name:    spi_top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`include "spi-defines.v"
`timescale 1ns / 1ps
module spi_top(
    input mosi,
    input ss,
    input sclk,
	 input clk,
    input rst,
    output miso,
	 output rst_led
    );
	 
	wire		[`DATA_W-1:0] 	data_in;
	wire	[`DATA_W-1:0] 	data_out;
	wire		[`ADDR_W-1:0] 	address;
	wire 				we;
	 
	 assign rst_led = rst;

	spi_slave spi_slave(
		.rst(rst),
		.sclk(sclk),
		.mosi(mosi),
		.miso(miso),
		.ss(ss),
		.clk(clk),
		.data_in(data_in),
		.data_out(data_out),
		.address(address),
		.we(we)
	);
	
	register_bank register_bank(
		.clk(clk),
		.rst(rst),
		.wr(we),
		.address(address),
		.data_in(data_out),
		.data_out(data_in)
	);
	
	
endmodule
