/* ****************************************************************************

  Description: SPI master

  Copyright (C) 2018 IObundle, Lda  All rights reserved

***************************************************************************** */


`timescale 1ns / 1ps
`include "spi_defines.vh"

module spi_master(

	//CONTROLLER INTERFACE
	input 			     clk,
	input 			     rst,
		  
	input [`SPI_DATA_W-1:0]      data_in,
	output reg [`SPI_DATA_W-1:0] data_out,
	input [`SPI_ADDR_W-1:0]      address,
	input 			     sel,
	input 			     read,
	input 			     write,
	output 			     interrupt,

	//SPI INTERFACE
	input 			     sclk,
	output 			     ss,
	output 			     mosi,
	input 			     miso
);

   //CONTROLLER SIDE SIGNALS
   reg 				     ctr_start;
   reg 				     ctr_ready;
   reg 				     ctr_ready_clr;
   reg [`SPI_DATA_W-1:0] 	     ctr_data2send;
   reg 				     ctr_data2send_en;
   reg 				     ctr_ss, ctr_ss_1, ctr_ss_2;
   reg 				     ctr_interrupt_en;
   reg 				     ctr_interrupt_en_en;
   reg                               rst_soft;
   wire                              rst_int;   
   reg [31:0]                        dummy_reg;
   reg                               dummy_reg_en;

   //SPI SIDE SIGNALS
   reg [5:0] 			     spi_counter;
   wire                              spi_start;
   reg                               spi_start_1;
   reg                               spi_start_2;
   reg [`SPI_DATA_W-1:0] 	     spi_data_rcvd;
   reg [`SPI_DATA_W-1:0] 	     spi_data2send;

   reg                               spi_nrst;
   reg                               spi_nrst_1;
   

   //
   //CONTROLLER SIDE LOGIC
   //
   
   assign rst_int = rst | rst_soft;
   
   // ADDRESS DECODER
   always @* begin
      ctr_start = 1'b0;
      data_out = `SPI_DATA_W'd0;
      ctr_data2send_en = 1'b0;
      ctr_interrupt_en_en = 1'b0;
      ctr_ready_clr = 1'b0;
      dummy_reg_en = 0;
      rst_soft = 1'b0;
      
      case (address)
	`SPI_INTRRPT_EN: ctr_interrupt_en_en = sel&write;
	`SPI_READY: data_out = { {`SPI_DATA_W-1{1'b0}}, ctr_ready & (spi_counter == 6'd63)};    //false path, no sync needed)
	`SPI_TX: begin
	   ctr_start = sel&write;
	   ctr_data2send_en = sel&write;
	end
	`SPI_RX: begin
	   data_out = spi_data_rcvd;                          //false path, no sync needed)
	   ctr_ready_clr = sel&read;
	end
	`SPI_VERSION: begin
	   data_out = `SPI_VERSION_STR; 
	end
	`SPI_SOFT_RST: begin
	   rst_soft = sel&write;
	end
        `DUMMY_REG: begin
           data_out = dummy_reg;
           dummy_reg_en = sel&write;
        end
	default:;
      endcase
   end
 

   // DATA TO SEND REG 
   always @ (posedge clk, posedge rst_int)
     if(rst_int)
       ctr_data2send <= 32'hF0F0F0F0;
     else if(ctr_data2send_en)
       ctr_data2send <= data_in;

   
   // RESAMPLE SLAVE SELECT SIGNAL
   always @ (posedge clk, posedge rst_int) begin
      if(rst_int) begin	 
	 ctr_ss_1 <= 1'b1;
	 ctr_ss_2 <= 1'b1;
	 ctr_ss <= 1'b1;
      end else begin
	 ctr_ss_1 <= ss;
	 ctr_ss_2 <= ctr_ss_1;
	 ctr_ss <= ctr_ss_2;
      end
   end

   // READY REG
   always @ (posedge clk, posedge rst_int)
     if(rst_int)
       ctr_ready <= 1'b0;
     else if(ctr_start | ctr_ready_clr)
       ctr_ready <= 1'b0;
     else if( ~ctr_ss & ctr_ss_2)
       ctr_ready <= 1'b1;
   
   // INTERRUPT ENABLE REG
   always @ (posedge clk, posedge rst_int)
     if(rst_int)
       ctr_interrupt_en <= 1'b0;
     else if(ctr_interrupt_en_en)
       ctr_interrupt_en <= data_in[0];

   // INETRRUPT SIGNAL
   assign interrupt = ctr_interrupt_en & ctr_ready;


   //dummy reg
   always @(posedge clk)
     if(rst_int)
       dummy_reg <= 32'b0;  
     else if(dummy_reg_en)
       dummy_reg <= data_in;

   

   //
   //
   // SPI SIDE LOGIC
   //
   //

   //spi_nrst
   always @ (negedge sclk, posedge rst_int)
     if(rst_int) begin
	spi_nrst <= 1'b0;
	spi_nrst_1 <= 1'b0;
     end else begin
	spi_nrst <= spi_nrst_1;
	spi_nrst_1 <= 1'b1;
     end
   
   //spi_start
   always @ (negedge sclk, posedge ctr_start)
     if(ctr_start) begin
	spi_start_2 <= 1'b1;
	spi_start_1 <= 1'b1;
     end else begin
	spi_start_2 <= spi_start_1;
	spi_start_1 <= 1'b0;
     end

   assign spi_start = spi_nrst & spi_start_2 & (spi_counter == 6'd63);

   //
   // START UP
   //

   //start signal for SPI side (false path, no sync needed) 
   //and counter
   always @ (negedge sclk, negedge spi_nrst) begin
      if (~spi_nrst)
	spi_counter <= 6'd63;
      else if (spi_start)
	spi_counter <= 6'd0;        
      else if (spi_counter != 6'd63)
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
       spi_data2send <= spi_data2send>>1;
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
   
endmodule
