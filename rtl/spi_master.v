/* ****************************************************************************

  Description: SPI master

  Copyright (C) 2018 IObundle, Lda  All rights reserved

***************************************************************************** */

/*
 Usage:
  
 WRITE
 
    Read: give an address, make rnw=1, issue a start pulse. Result will be at 
    data_out when ready=1 again.
 
    Write: give an address, make rnw=0, issue a start pulse. Wait for ready=1.
 
 */

`timescale 1ns / 1ps
`include "spi_defines.v"

module spi_master(
	input 			     clk,
	input 			     rst,
		  
	//SPI INTERFACE
	input 			     sclk,
	output reg 		     ss,
	output 			     mosi,
	input 			     miso,
		  
	//CONTROL INTERFACE
	input [`DATA_W-1:0]      data_in,
	output reg [`DATA_W-1:0] data_out,
	input [`ADDR_W-1:0] 	     address,
	input 			     we,
	input 			     sel
);

   //SPI SIDE SIGNALS

   reg [5:0]				 spi_counter;
   reg 					 spi_rst, spi_rst_1, spi_rst_2;
   reg 					 spi_start;
   reg 					 spi_start_1;
   reg [`DATA_W-1:0] 			 spi_data_rcvd;
   reg [`DATA_W-1:0] 			 spi_data2send;

   //CONTROL SIDE SIGNALS

   reg 					 ctr_start;
   reg 					 ctr_ready;
   reg [`DATA_W-1:0] 			 ctr_data_rcvd;
   reg [`DATA_W-1:0] 			 ctr_data2send;
   reg               			 ctr_data2send_en;
   reg [7:0] 				 start_counter;
   reg  				 start_counter_en;
   reg 					 ctr_ss;
   reg 					 ctr_ss_1;
  

   //SPI SIDE LOGIC

   //reset sync
   always @ (negedge sclk, negedge ~rst)
     if(~rst) begin
	spi_rst <= 1'b1;
	spi_rst_1 <= 1'b1;
	spi_rst_1 <= 1'b1;
     end else begin
	spi_rst <= spi_rst_2;
	spi_rst_2 <= spi_rst_1;
	spi_rst_1 <= 1'b0;
     end
   
   //counter
   always @ (negedge sclk)
      if(spi_start)
	spi_counter <= 6'd0;
      else if (spi_counter != 5'd31)
	spi_counter <= spi_counter + 1'b1;

   // spi slave select
   assign ss = (spi_counter < 6'd16 || spi_counter > 6'd47)? 1'b1 : 1'b0;

   //spi start
   always @ (negedge sclk) begin 
     spi_start_1 <= ctr_start;
     spi_start <= spi_start_1;
   end
   
   //data to send register
   always @ (negedge sclk)
     if(~ss)
       spi_data2send <= ctr_data2send>>1;
     else
       spi_data2send <= ctr_data2send;
   // spi master output slave input
   assign mosi = spi_data2send[0];
   
   //data received register
   always @ (negedge sclk)
     if(~ss) begin 
	spi_data_rcvd[`DATA_W-1] <= miso;
	spi_data_rcvd[`DATA_W-2:0] <= spi_data_rcvd[`DATA_W-1:1];
     end
   
   // spi read input data
   always @ (posedge sclk)
     if(~ss)
       spi_data_rcvd[31] <= miso;
   

   //CONTROLLER SIDE LOGIC

   // resample ready signal from SPI side
   always @(posedge clk) begin
      ctr_ready_1 <= ss;
      ctr_ready <= ctr_ready_1;
   end

   // address decoder
   always @* begin
      ctr_start = 1'b0;
      data_out = `DATA_W'd0;
      ctr_data2send_en = 1'b0;
      case (address)
	`START_REG: ctr_start = sel&we;                       //start register
	`READY_REG: data_out = { {`DATA_W-1{1'b0}}, ctr_ready}; //ready register
	`IN_REG: ctr_data2send_en = sel&we;
	`OUT_REG: data_out = ctr_data_rcvd;
	default:;
      endcase
   end

   // write data to send in respective register 
   always @ (posedge clk)
     if(ctr_data2send_en)
       ctr_data2send <= data_in;
   
   //start signal for SPI side
   assign spi_start = ~start_counter[7];
   
   always @ (posedge clk)
     if(ctr_start)
       start_counter <= 8'd0;
     else if(start_counter != 8'hFF)
       start_counter <= start_counter + 1'b1;

  // ctr_ready sync 
   always @ (posedge clk) begin
      ctr_ss_1 <= ss;
      ctr_ss <= ctr_ss_1;
      ctr_ready <= ctr_ss;
   end
 
   
endmodule
