/* ****************************************************************************
  This Source Code Form is subject to the terms of the
  Open Hardware Description License, v. 1.0. If a copy
  of the OHDL was not distributed with this file, You
  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

  Description: SPI front end

   Copyright (C) 2014 Authors

  Author(s): Jose T. de Sousa <jose.t.de.sousa@gmail.com>


***************************************************************************** */

`include "spi-defines.v"

module spi_fe (
	       input 		    clk,
	       input 		    rst,
		  // SPI port
	       input 		    sclk, //serial clock
	       input 		    ss, // slave select (active low)
	       input 		    mosi, // MasterOut SlaveIN
	       output reg		    miso, // MasterIn SlaveOut

	       //parallel interface
	       input [`DATA_W-1:0]  data_in,
	       output [`DATA_W-1:0] data_out,
	       output 		    ss_pos_edge,
	       output 		    ss_neg_edge
		  );

   wire 		      sclk;


   reg 			      ss_sample;
   reg [2:0] 		      sclk_samples;
   
   wire 		      sclk_pos_edge;

   reg [`DATA_W-1:0] 	      data_rx_reg, data_tx_reg;
 	      
   
   assign ss_pos_edge = ~ss_sample & ss & sclk_neg_edge;     //posedge detect
   assign ss_neg_edge = ss_sample & ~ss & sclk_neg_edge;     //negedge detect 
   
   assign sclk_pos_edge = ~sclk_samples[2] & sclk_samples[1];     //posedge detect
   assign sclk_neg_edge = sclk_samples[2] & ~sclk_samples[1];     //negedge detect 
   

   always @(posedge clk, posedge rst) begin //sampling
      if(rst)
	  ss_sample <= 1'b1;
      else begin
          sclk_samples[2:1] <= sclk_samples[1:0];
          sclk_samples[0] <= sclk;
          if(sclk_neg_edge)
	     ss_sample <= ss;
      end
   end 


   always @(posedge clk) begin //read from mosi
      if(~ss & sclk_pos_edge) begin
	 data_rx_reg <= {data_rx_reg[`DATA_W-2:0], mosi};
      end
   end

   assign data_out = data_rx_reg;
   
   
   always @ (posedge clk) begin //write to miso
      if (ss_neg_edge & sclk_neg_edge)
	data_tx_reg <= data_in;
      else if (~ss & sclk_neg_edge)
	data_tx_reg[`DATA_W-1:1] <= data_tx_reg[`DATA_W-2:0];
   end

   always @ * miso = data_tx_reg[`DATA_W-1];
    
endmodule 
