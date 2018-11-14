/*****************************************************************************

  Description: SPI slave

  Copyright (C) 2018 IObundle, Lda All rights reserved

******************************************************************************/

`timescale 1ns / 1ps
`include "spi_defines.vh"

module spi_slave(
	input 			     clk,
	input 			     rst,

	//SPI INTERFACE
	input 			     sclk,
	input 			     ss,
	input 			     mosi,
	output 			     miso,

	//CONTROL INTERFACE
	input [`SPI_DATA_W-1:0]      data_in,
	output reg [`SPI_DATA_W-1:0] data_out,
	input [`SPI_ADDR_W-1:0]      address,
	input 			     we,
	input 			     sel,
	output 			     interrupt
);

   //SPI SIDE SIGNALS
   reg 				 spi_rst, spi_rst_1, spi_rst_2;
   reg [`SPI_DATA_W-1:0] 	 spi_data_rcvd;
   reg [`SPI_DATA_W-1:0] 	 spi_data2send;

   //CONTROL SIDE SIGNALS
   reg 				 ctr_ready;
   reg 				 ctr_clr_ready;
   reg 				 ctr_ss;
   reg 				 ctr_ss_1;
   reg [`SPI_DATA_W-1:0] 	 ctr_data2send;
   reg 				 ctr_data2send_en;


   //
   //SPI SIDE LOGIC
   //
   
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

   //data to send shift register
   always @ (negedge sclk)
     if(~ss)
       spi_data2send <= ctr_data2send>>1;
     else
       spi_data2send <= ctr_data2send;
   // spi master input slave output
   assign miso = spi_data2send[0];
   
   //data received shift register
   always @ (negedge sclk)
     if(~ss) begin 
	spi_data_rcvd[`SPI_DATA_W-1] <= mosi;
	spi_data_rcvd[`SPI_DATA_W-2:0] <= spi_data_rcvd[`SPI_DATA_W-1:1];
     end

   
   //
   //CONTROLLER SIDE LOGIC
   //
   
   // address decoder
   always @* begin
      data_out = `SPI_DATA_W'd0;
      ctr_data2send_en = 1'b0;
      ctr_clr_ready = 1'b0;
      
      case (address)
	`SPI_READY: begin
	   data_out = { {`SPI_DATA_W-1{1'b0}}, ctr_ready}; 
	end
	`SPI_TX: ctr_data2send_en = sel&we;
	`SPI_RX: begin 
	   data_out = spi_data_rcvd;
	   ctr_clr_ready = sel&~we;
	end
	default:;
      endcase
   end

   //
   // SEND
   //
 
   // write data to send in respective register 
   always @ (posedge clk)
     if(ctr_data2send_en)
       ctr_data2send <= data_in;
   
   //
   // RECEIVE
   //

   // ctr_ready sync 
   always @ (posedge clk) begin
      ctr_ss <= ss;
      ctr_ss <= ctr_ss_1;
      if(interrupt)
	ctr_ready <= 1'b1;
      else if(ctr_clr_ready)
	ctr_ready <= 1'b0;
   end
     
   // interrupt 
   assign interrupt = ctr_ss & ~ctr_ss_1;
   
endmodule
