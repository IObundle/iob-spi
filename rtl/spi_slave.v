/*****************************************************************************

  Description: SPI slave

  Copyright (C) 2018 IObundle, Lda All rights reserved

******************************************************************************/

/*
 Usage:

    1. Poll READY until it is one or wait for INTERRUPT
    2. Read SPI_RX address
    3. Write the response word to send to the SPI_TX address
  
 */

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

   //data to send shift register
   always @ (negedge sclk)
     if(ss)
       spi_data2send <= ctr_data2send;
     else
       spi_data2send <= spi_data2send>>1;
   
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
   // CONTROL
   //

   // resample slave select
   always @ (posedge clk, posedge rst) begin
      if(rst) begin	 
	 ctr_ss_1 <= 1'b1;
	 ctr_ss <= 1'b1;
      end else begin
	 ctr_ss_1 <= ss;
	 ctr_ss <= ctr_ss_1;
      end
   end

   // ctr_ready
   always @ (posedge clk, posedge rst)
     if (rst)
       ctr_ready <= 1'b0;
     else if (ctr_clr_ready)
       ctr_ready <= 1'b0;
     else if (interrupt)
       ctr_ready <= 1'b1;

     
   // interrupt 
   assign interrupt = ~ctr_ss & ctr_ss_1;
   
endmodule
