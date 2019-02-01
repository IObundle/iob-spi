/* ****************************************************************************

  Description: SPI master

  Copyright (C) 2018 IObundle, Lda  All rights reserved

***************************************************************************** */


`timescale 1ns / 1ps
`include "spi_defines.vh"

module spi_master(

	//CONTROLLER INTERFACE
	input                        clk,
	input                        rst,
		  
	input [`SPI_DATA_W-1:0]      data_in,
	output reg [`SPI_DATA_W-1:0] data_out,
	input [`SPI_ADDR_W-1:0]      address,
	input                        sel,
	input                        read,
	input                        write,
	output                       interrupt,

	//SPI INTERFACE
	input                        sclk,
	output reg                   ss,
	output                       mosi,
	input                        miso
);

   //CONTROLLER SIDE SIGNALS
   reg 				     ctr_ready;
   reg                               ctr_ready_clr;
   reg [`SPI_DATA_W-1:0] 	     ctr_data2send;
   reg 				     ctr_data2send_en;
   reg [2:0]			     ctr_ss;
   reg 				     ctr_interrupt_en;
   reg 				     ctr_interrupt_en_en;
   reg                               rst_soft;
   wire                              rst_int;   
   reg [31:0]                        dummy_reg;
   reg                               dummy_reg_en;

   //SPI SIDE SIGNALS
   reg [5:0] 			     spi_counter;
   reg [1:0]                         spi_start;
   reg [`SPI_DATA_W-1:0] 	     spi_data_rcvd;
   reg [`SPI_DATA_W-1:0] 	     spi_data2send;

   reg [1:0]                         spi_nrst;
   

   //
   //CONTROLLER SIDE LOGIC
   //
   
   assign rst_int = rst | rst_soft;
   
   // ADDRESS DECODER
   always @* begin
      data_out = `SPI_DATA_W'd0;
      ctr_data2send_en = 1'b0;
      ctr_ready_clr = 1'b0;
      ctr_interrupt_en_en = 1'b0;
      dummy_reg_en = 0;
      rst_soft = 1'b0;
      
      case (address)
	`SPI_INTRRPT_EN: ctr_interrupt_en_en = sel&write;
	`SPI_READY: data_out = {31'd0, ctr_ready};
	`SPI_TX: ctr_data2send_en = sel&write;
	`SPI_RX: begin 
           data_out = spi_data_rcvd;
	   ctr_ready_clr = sel&read;
        end
	`SPI_VERSION: data_out = `SPI_VERSION_STR; 
	`SPI_SOFT_RST: rst_soft = sel&write;
        `DUMMY_REG: begin
           data_out = dummy_reg;
           dummy_reg_en = sel&write;
        end
	default:;
      endcase
   end
 
   // READY REGISTER
   always @ (posedge clk, posedge rst_int)
     if(rst_int)
       ctr_ready <= 1'b1;
     else if(ctr_data2send_en | ctr_ready_clr)
       ctr_ready <= 1'b0;
     else if( ~ctr_ss[2] & ctr_ss[1])
       ctr_ready <= 1'b1;
   
   // DATA TO SEND REG 
   always @ (posedge clk)
     if(ctr_data2send_en)
       ctr_data2send <= data_in;

   // INTERRUPT ENABLE REG
   always @ (posedge clk, posedge rst_int)
     if(rst_int)
       ctr_interrupt_en <= 1'b0;
     else if(ctr_interrupt_en_en)
       ctr_interrupt_en <= data_in[0];

   // INTERRUPT SIGNAL
   assign interrupt = ctr_interrupt_en & ctr_ready;

   // DUMMY REG
   always @(posedge clk)
     if(rst_int)
       dummy_reg <= 32'b0;  
     else if(dummy_reg_en)
       dummy_reg <= data_in;


   // RESAMPLE SLAVE SELECT SIGNAL
   always @ (posedge clk, posedge rst_int)
      if(rst_int)
	ctr_ss <= 3'b111;
      else
	ctr_ss <= {ctr_ss[1:0], ss};



   //
   //
   // SPI SIDE LOGIC
   //
   //

   //spi_nrst sync
   always @ (negedge sclk, posedge rst_int)
     if(rst_int)
	spi_nrst <= 2'b00;
     else
       spi_nrst <= {spi_nrst[0], 1'b1};

   //spi_start
   always @ (negedge sclk, posedge ctr_data2send_en)
     if(ctr_data2send_en)
	spi_start <= 2'b11;
     else
	spi_start <= {spi_start[0], 1'b0};

   //spi control counter
   always @ (negedge sclk, negedge spi_nrst[1])
      if (!spi_nrst[1])
	spi_counter <= 6'd63;
      else if (spi_start[1])
	spi_counter <= 6'd0;        
      else if (spi_counter != 6'd63)
	spi_counter <= spi_counter + 1'b1;
   
   // spi slave select
   always @ (negedge sclk, negedge spi_nrst[1])
      if(!spi_nrst[1])
        ss <= 1'b1;
      else if (spi_counter == 6'd15)
        ss <= 1'b0;
      else if (spi_counter == 6'd47)
        ss <= 1'b1;
      
   //data to send register
   always @ (negedge sclk)
     if(spi_counter == 6'd8)
       spi_data2send <= ctr_data2send; // false path, no sync needed
     else if(~ss)
       spi_data2send <= spi_data2send>>1;

   // spi master output slave input
   assign mosi = spi_data2send[0];
   
   //DATA RECEIVED REGISTER
   always @ (posedge sclk)
     if(~ss) //receive miso and shift right
       spi_data_rcvd <= {miso, spi_data_rcvd[`SPI_DATA_W-1:1]};  
   
endmodule
