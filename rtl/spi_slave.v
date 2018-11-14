/*****************************************************************************

  Description: SPI slave

  Copyright (C) 2018 IObundle, Lda All rights reserved

******************************************************************************/

`timescale 1ns / 1ps
`include "spi_defines.v"

module spi_slave(
	input 			 clk,
	input 			 rst,

	//SPI INTERFACE
	input 			 sclk,
	input 			 ss,
	input 			 mosi,
	output 			 miso,

	//CONTROL INTERFACE
	input [`DATA_W-1:0] 	 data_in,
	output reg [`DATA_W-1:0] data_out,
	input [`ADDR_W-1:0] 	 address,
	input 			 we,
	input 			 sel,
	output 			 interrupt
);

   //SPI SIDE SIGNALS
   reg 					 spi_rst, spi_rst_1, spi_rst_2;
   reg [`DATA_W-1:0] 			 spi_data_rcvd;
   reg [`DATA_W-1:0] 			 spi_data2send;

   //CONTROL SIDE SIGNALS
   reg 					 ctr_ready;
   reg 					 ctr_ss;
   reg 					 ctr_ss_1;
   reg [`DATA_W-1:0] 			 ctr_data2send;
   reg [`DATA_W-1:0] 			 ctr_data_rcvd;
   reg               			 ctr_data2send_en;


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
	spi_data_rcvd[`DATA_W-1] <= mosi;
	spi_data_rcvd[`DATA_W-2:0] <= spi_data_rcvd[`DATA_W-1:1];
     end

   
   //CONTROLLER SIDE LOGIC

   // address decoder
   always @* begin
      data_out = `DATA_W'd0;
      ctr_data2send_en = 1'b0;
      case (address)
	`READY_REG: data_out = { {`DATA_W-1{1'b0}}, ctr_ready};   //ready register
	`IN_REG: ctr_data2send_en = sel&we;
	`OUT_REG: data_out = ctr_data_rcvd;
	default:;
      endcase
   end

   // write data to send in respective register 
   always @ (posedge clk)
     if(ctr_data2send_en)
       ctr_data2send <= data_in;
   
   // read data received from spi
   assign data_in = spi_data_rcvd;
   
   
   // ctr_ready sync 
   always @ (posedge clk) begin
      ctr_ss_1 <= ss;
      ctr_ss <= ctr_ss_1;
      ctr_ready <= ctr_ss;
   end
     
   // interrupt 
   assign interrupt = ctr_ready & ~ctr_ss;
   
endmodule
