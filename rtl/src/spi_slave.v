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
	input 			     sel,
	input 			     read,
	input 			     write,
	output 			     interrupt
);

   //SPI SIDE SIGNALS
   reg [`SPI_DATA_W-1:0] 	 spi_data_rcvd;
   reg [`SPI_DATA_W-1:0] 	 spi_data2send;

   //CONTROL SIDE SIGNALS
   reg 				 ctr_ready;
   reg 				 ctr_ready_clr;
   reg 				 ctr_ss;
   reg 				 ctr_ss_1, ctr_ss_2;
   reg [`SPI_DATA_W-1:0] 	 ctr_data2send;
   reg 				 ctr_data2send_en;
   reg 				 ctr_interrupt_en;
   reg 				 ctr_interrupt_en_en;

   reg [31:0]                    dummy_reg;
   reg                           dummy_reg_en;

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
   always @ (posedge sclk)
     if(~ss) begin 
	spi_data_rcvd[`SPI_DATA_W-1] <= mosi;
	spi_data_rcvd[`SPI_DATA_W-2:0] <= spi_data_rcvd[`SPI_DATA_W-1:1];
     end

   
   //
   //CONTROLLER SIDE LOGIC
   //
   
   //dummy reg
   always @(posedge clk)
     if(rst)
       dummy_reg <= 32'b0;  
     else if(dummy_reg_en)
       dummy_reg <= data_in;
   
   //
   // ADDRESS DECODER
   //
   always @* begin
      data_out = `SPI_DATA_W'd0;
      ctr_data2send_en = 1'b0;
      ctr_ready_clr = 1'b0;
      ctr_interrupt_en_en = 1'b0;
      dummy_reg_en = 0;
    
      case (address)
	`SPI_INTRRPT_EN: ctr_interrupt_en_en = sel&write;
	`SPI_READY: data_out = { {`SPI_DATA_W-1{1'b0}}, ctr_ready}; 
	`SPI_TX: ctr_data2send_en = sel&write;
	`SPI_RX: begin 
	   data_out = spi_data_rcvd;
	   ctr_ready_clr = sel&read;
	end
        `DUMMY_REG: begin
           data_out = dummy_reg;
           dummy_reg_en = sel&write;
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
	 ctr_ss_2 <= 1'b1;
	 ctr_ss <= 1'b1;
      end else begin
	 ctr_ss_1 <= ss;
	 ctr_ss_2 <= ctr_ss_1;
	 ctr_ss <= ctr_ss_2;
      end
   end

   // CTR_READY
   always @ (posedge clk, posedge rst)
     if (rst)
       ctr_ready <= 1'b0;
     else if (ctr_ready_clr)
       ctr_ready <= 1'b0;
     else if (~ctr_ss & ctr_ss_2)
       ctr_ready <= 1'b1;

     
   // INTERRUPT 
    always @ (posedge clk)
      if(rst)
	ctr_interrupt_en <= 1'b0;
      else if(ctr_interrupt_en_en)
	ctr_interrupt_en <= data_in[0];

   assign interrupt = ctr_interrupt_en & ctr_ready;
   
endmodule
