/* ****************************************************************************
  This Source Code Form is subject to the terms of the
  Open Hardware Description License, v. 1.0. If a copy
  of the OHDL was not distributed with this file, You
  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

  Description: SPI protocol

   Copyright (C) 2014 Authors

  Author(s): Guilherme Luz <gui_luz_93@hotmail.com>
             Jose T. de Sousa <jose.t.de.sousa@gmail.com>
             Francisco Nunes <ftcnunes@gmail.com>

***************************************************************************** */

`timescale 1ns / 1ps

`include "rcntlr_defines.v"

module spi_protocol (
		     input 			  clk,
		     input 			  rst,
		     input [`SPI_DATA_W-1:0] 	  data_fe_in ,
		     input [`SPI_DATA_W-1:0] 	  data_in,
		     input 			  ss_pos_edge,
		     input 			  ss_neg_edge,
		     output reg [`SPI_DATA_W-1:0] data_fe_out,
		     output reg [`SPI_DATA_W-1:0] data_out,
		     output reg [`SPI_ADDR_W-1:0] address,
		     output reg 		  we
		     );

   reg [1:0] 					  state;
   reg 						  rnw;

   //assign data_fe_out = data_in & ~state[1] & state[0];

   always @ (posedge clk, posedge rst) begin // states
      if (rst) begin
	 state       <= 2'b0;
	 rnw         <= 1'b1;
	 data_fe_out <= `SPI_DATA_W'b0;
         we          <= 1'b0;
         address     <= 0;
      end else
	case (state)
	  2'b00: begin // idle
	     if (ss_pos_edge) begin
		state   <= 2'b01;
		address <= data_fe_in[`SPI_ADDR_W-1:0];
                rnw     <= data_fe_in[`SPI_ADDR_W];
	     end
	  end
	  2'b01: begin // read config word			
	     if (rnw)
	       data_fe_out  <= data_in;			
	     if (ss_pos_edge) begin
		data_fe_out <= `SPI_DATA_W'b0;
		state       <= 2'b10;
		if (~rnw) begin
		   data_out <= data_fe_in;	
                   we       <= 1'b1;
                end
	     end 
	  end
	  2'b10: begin // data read/write
             we <= 1'b0;
	     if (ss_neg_edge)
	       state <= 2'b00;
	  end
	  default: begin
	  end
	endcase
   end

endmodule
