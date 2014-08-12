/* ****************************************************************************
  This Source Code Form is subject to the terms of the
  Open Hardware Description License, v. 1.0. If a copy
  of the OHDL was not distributed with this file, You
  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

  Description: SPI slave

   Copyright (C) 2014 Authors

  Author(s): 	Jose T. de Sousa <jose.t.de.sousa@gmail.com>
		Guilherme Luz <gui_luz_93@hotmail.com>

***************************************************************************** */

`include "spi-defines.v"
`timescale 1ns / 1ps

module spi_slave(
	input 				clk,
	input				rst,
	//spi slave signals
	input 				sclk,
	input				ss,
	input				mosi,
	output				miso,
	//signals used in reg_bank
	input		[`DATA_W-1:0] 	data_in,
	output	[`DATA_W-1:0] 	data_out,
	output		[`ADDR_W-1:0] 	address,
	output 				we


);
	//signals between spi_fe and spi_protocol
	wire 				ss_pos_edge;
	wire 				ss_neg_edge;
	wire 		[`DATA_W-1:0] 	data_fe_in;
	wire 		[`DATA_W-1:0] 	data_fe_out;


	spi_fe spi_fe (
	       	.clk(clk),
	       	.rst(rst),
	       	.sclk(sclk), 
	       	.ss(ss), 
	       	.mosi(mosi), 
	       	.miso(miso), 
	       	.data_in(data_fe_in),
	       	.data_out(data_fe_out),
	       	.ss_pos_edge(ss_pos_edge),
	       	.ss_neg_edge(ss_neg_edge)
	);


	spi_protocol spi_protocol (
		.clk(clk),
		.rst(rst),
		.data_fe_in(data_fe_out) ,
		.data_in(data_in),
		.ss_pos_edge(ss_pos_edge),
		.ss_neg_edge(ss_neg_edge),
		.data_fe_out(data_fe_in),
		.data_out(data_out),
		.address(address),
		.we(we)
	);


endmodule
