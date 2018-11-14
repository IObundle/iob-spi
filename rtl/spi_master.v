/* ****************************************************************************

  Description: SPI master

  Copyright (C) 2018 IObundle, Lda  All rights reserved

***************************************************************************** */

/*
 Usage:

 READ
    1. Write anything to the SPI_START address
    2. Poll READY until it is one or wait for INTERRUPT
    3. Read SPI_RX address

 WRITE
    1. Write the word to send to the SPI_TX address
    2. Write anything to the SPI_START address
    3. Poll READY until it is 1 or wait for INTERRUPT
  
 */

`timescale 1ns / 1ps
`include "spi_defines.vh"

module spi_master(
	input 			     clk,
	input 			     rst,
		  
	//SPI INTERFACE
	input 			     sclk,
	output reg 		     ss,
	output 			     mosi,
	input 			     miso,
		  
	//CONTROL INTERFACE
	input [`SPI_DATA_W-1:0]      data_in,
	output reg [`SPI_DATA_W-1:0] data_out,
	input [`SPI_ADDR_W-1:0]      address,
	input 			     we,
	input 			     sel,
	output 			     interrupt
);

   //SPI SIDE SIGNALS

   reg 				     spi_rst, spi_rst_1, spi_rst_2;
   reg [5:0] 			     spi_counter;
   reg 				     spi_start;
   reg [`SPI_DATA_W-1:0] 	     spi_data_rcvd;
   reg [`SPI_DATA_W-1:0] 	     spi_data2send;

   //CONTROL SIDE SIGNALS

   reg 				     ctr_start;
   reg 				     ctr_ready;
   reg [`SPI_DATA_W-1:0] 	     ctr_data2send;
   reg 				     ctr_data2send_en;
   reg [6:0] 			     start_counter;
   reg 				     start_counter_en;
   reg 				     ctr_ss, ctr_ss_1;
   


   //
   //
   // SPI SIDE LOGIC
   //
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
   
   //
   // START UP
   //

   //start signal for SPI side (false path, no sync needed) 
   //and counter
   always @ (negedge sclk) begin
      spi_start <= ~start_counter[6];
      if(spi_start)
	spi_counter <= 6'd0;
      else if (spi_counter != 5'd31)
	spi_counter <= spi_counter + 1'b1;
   end
   
   // spi slave select
   assign ss = (spi_counter < 6'd16 || spi_counter > 6'd47)? 1'b1 : 1'b0;
   
   //
   // SEND
   //

   //data to send register
   always @ (negedge sclk)
     if(~ss)
       spi_data2send <= ctr_data2send>>1;
     else
       spi_data2send <= ctr_data2send; // false path, no sync needed
   // spi master output slave input
   assign mosi = spi_data2send[0];
   
   //
   // RECEIVE
   //

   //data received register
   always @ (negedge sclk)
     if(~ss) begin 
	spi_data_rcvd[`SPI_DATA_W-1] <= miso;                              //miso input 
	spi_data_rcvd[`SPI_DATA_W-2:0] <= spi_data_rcvd[`SPI_DATA_W-1:1];  //shift right
     end
   
   
   //
   //
   //CONTROLLER SIDE LOGIC
   //
   //
   

   //
   // ADDRESS DECODER
   //
   always @* begin
      ctr_start = 1'b0;
      data_out = `SPI_DATA_W'd0;
      ctr_data2send_en = 1'b0;
      case (address)
	`SPI_START: ctr_start = sel&we;                             
	`SPI_READY: data_out = { {`SPI_DATA_W-1{1'b0}}, ss};    //false path, no sync needed)
	`SPI_TX: ctr_data2send_en = sel&we;                         
	`SPI_RX: data_out = spi_data_rcvd;                          //false path, no sync needed)
	default:;
      endcase
   end
 
   //
   //  STARTP UP
   //
   always @ (posedge clk)
     if(ctr_start)
       start_counter <= 8'd0;
     else if(start_counter != 8'hFF)
       start_counter <= start_counter + 1'b1;
 

   //
   // SEND
   //
   
   // write data to send 
   always @ (posedge clk)
     if(ctr_data2send_en)
       ctr_data2send <= data_in;

   
   //
   // RECEIVE
   //

   // ctr_ready sync 
   always @ (posedge clk) begin
      ctr_ss_1 <= ss;
      ctr_ss <= ctr_ss_1;
   end
     
   // interrupt 
   assign interrupt = ctr_ss & ~ctr_ss_1;
   
endmodule
