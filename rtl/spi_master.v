/* ****************************************************************************
  This Source Code Form is subject to the terms of the
  Open Hardware Description License, v. 1.0. If a copy
  of the OHDL was not distributed with this file, You
  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

  Description: SPI master

   Copyright (C) 2014 Authors

  Author(s): 	Jose T. de Sousa <jose.t.de.sousa@gmail.com>

***************************************************************************** */

/*
 Usage:
 
    Clock: sclk should be 5x slower than slave's system clock.
 
    Reset: the reset pulse must overlap sclk falling edge.
 
    Read: give an address, make rnw=1, issue a start pulse. Result will be at 
    data_out when ready=1 again.
 
    Write: give an address, make rnw=0, issue a start pulse. Wait for ready=1.
 
 */

`include "spi_defines.v"
`timescale 1ns / 1ps

`define IDLE 2'b00
`define SEND_ADDR 2'b01
`define SEND_PAUSE 2'b10
`define ST_DATA 2'b11

module spi_master(
	input 			     rst,
	//spi  signals
	input 			     sclk,
	output reg 		     ss,
	output 			     mosi,
	input 			     miso,
	//signals used in parallel interface
	input [`SPI_DATA_W-1:0]      data_in,
	output reg [`SPI_DATA_W-1:0] data_out,
	input [`SPI_ADDR_W-1:0]      address,
	input 			     rnw,
	input 			     start,
	output reg 		     ready
);


   reg [4:0]				 systimer;
   reg [1:0] 				 state;
   
   reg [`SPI_DATA_W-1:0] 		 dreg;
   

   assign mosi = dreg[`SPI_DATA_W-1];
   

   //send address and data
   always @ (negedge sclk) begin

      if (rst == 1'b1) begin
	 state <= `IDLE;
	 ready <= 1'b1;
	 ss <= 1'b1;
      end
      else begin
	 systimer <= systimer- 1'b1;
	 if(systimer == 5'd0)
	   systimer <= 5'd0;
	 
	 dreg <= dreg << 1;
	 
	 case(state)
	   `IDLE: begin
	      ss <= 1'b1;
	      systimer <=5'd`SPI_ADDR_W;
	      dreg[`SPI_DATA_W - 1] <= rnw;
	      dreg[`SPI_DATA_W-2 -: `SPI_ADDR_W] <= address;
	      if(start == 1'b1) begin
		 state <= `SEND_ADDR;
		 ss <= 1'b0;
		 ready <= 1'b0;
	      end
	   end
	   `SEND_ADDR: begin
	      if(systimer == 5'd0) begin
		 ss <= 1'b1;
		 state <= `SEND_PAUSE;
	      end 
	   end 
	   `SEND_PAUSE: begin
	      state <= `ST_DATA;
	      systimer <= 32'd`SPI_DATA_W - 1'b1;
	      dreg <= data_in;
	      ss <= 1'b0;	 	      
	   end
	   `ST_DATA: begin
	      if(systimer == 5'd0) begin
		 ss <= 1'b1;
		 ready <= 1'b1;
		 state <= `IDLE;
	      end 
	   end 
	 endcase
      end // else: !if(rst == 1'b1)
      
   end 


   //sample input data
   always @ (posedge sclk) begin
      if(state == `ST_DATA) begin
	 data_out[0] <= miso;
	 data_out[31:1] <= data_out[30:0];
      end
   end

   
endmodule
