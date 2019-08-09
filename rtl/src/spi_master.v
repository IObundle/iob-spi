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

	//SPI INTERFACE
	input                        sclk,
	output reg                   ss,
	output                       mosi,
	input                        miso
);

   //CONTROLLER SIDE SIGNALS
   reg [1:0]                         ctr_ready;

   reg [`SPI_DATA_W-1:0]             ctr_data_rcvd[1:0];

   reg [`SPI_DATA_W-1:0] 	     ctr_data2send;
   reg 				     ctr_data2send_en;

   reg                               rst_soft;
   wire                              rst_int;   

   reg [31:0]                        dummy_reg;
   reg                               dummy_reg_en;

   //SPI SIDE SIGNALS
   reg [5:0] 			     spi_counter;
   reg [1:0]                         spi_start;
   reg [`SPI_DATA_W-1:0] 	     spi_data_rcvd;
   reg [`SPI_DATA_W-1:0] 	     spi_data2send;

   reg [1:0]                         spi_rst;   
   reg [`SPI_DATA_W-1:0]	     spi_ctr_data2send[1:0]; 
   reg                               spi_ready;
   
   
   //
   //CONTROLLER SIDE LOGIC
   //

   //reset 
   assign rst_int = rst | rst_soft;


   // READY REGISTER SYNC
   always @ (posedge clk, posedge rst_int)
     if (rst_int)
       ctr_ready <= 2'b0;
     else 
       ctr_ready <= {ctr_ready[0], spi_ready};
     
   // DATA RECEIVED REGISTER SYNC
   always @ (posedge clk, posedge rst_int)
     if (rst_int) begin
       ctr_data_rcvd[0] <= 0;
       ctr_data_rcvd[1] <= 0;
     end else begin
       ctr_data_rcvd[0] <= spi_data_rcvd;
       ctr_data_rcvd[1] <= ctr_data_rcvd[0];
     end

   
   // ADDRESS DECODER

   //write
   always @* begin
      ctr_data2send_en = 1'b0;
      dummy_reg_en = 0;
      rst_soft = 1'b0;
      
      case (address)
	`SPI_TX: ctr_data2send_en = sel&write;
	`SPI_SOFT_RST: rst_soft = sel&write;
        `DUMMY_REG: dummy_reg_en = sel&write;
	default:;
      endcase
   end
 
   //read
   always @* begin
      data_out = `SPI_DATA_W'd0;
      if(sel&read)
        case (address)
	  `SPI_READY: data_out = {31'd0, ctr_ready[1]};
	  `SPI_RX: data_out = ctr_data_rcvd[1];
	  `SPI_VERSION: data_out = `SPI_VERSION_STR; 
          `DUMMY_REG: data_out = dummy_reg;
	  default:;
        endcase
   end 



   // DATA TO SEND REG 
   always @ (posedge clk, posedge rst_int)
     if(rst_int)
       ctr_data2send <= 0;
     else if(ctr_data2send_en)
       ctr_data2send <= data_in;

   // DUMMY REG
   always @(posedge clk,  posedge rst_int)
     if(rst_int)
       dummy_reg <= 32'b0;  
     else if(dummy_reg_en)
       dummy_reg <= data_in;


   //
   //
   // SPI SIDE LOGIC
   //
   //

   //spi_rst  synchronizer
   always @ (negedge sclk, posedge rst_int)
     if(rst_int)
	spi_rst <= 2'b11;
     else 
        spi_rst <= {spi_rst[0], 1'b0};

   // spi_ctr_data2send synchronizer                    
   always @(posedge sclk) begin                                         
      spi_ctr_data2send[0] <= ctr_data2send;       
      spi_ctr_data2send[1] <= spi_ctr_data2send[0];
   end                                           

   //spi_start
   always @ (negedge sclk, posedge ctr_data2send_en)
     if(ctr_data2send_en)
	spi_start <= 2'b11;
     else
	spi_start <= {spi_start[0], 1'b0};


   //ready register
   reg  ss_reg;
   always @(posedge sclk, posedge spi_rst[1])
     if(spi_rst[1]) begin
        ss_reg <= 1'b1;
        spi_ready <= 1'b1;
     end else begin
        ss_reg <= ss;
        spi_ready <= ss_reg;
     end

   
   //data to send register
   always @ (negedge sclk, posedge spi_rst[1])
     if (spi_rst[1])
       spi_data2send <= 0;
     else if(spi_counter == 6'd8)
       spi_data2send <= spi_ctr_data2send[1]; //load
     else if(~ss)
       spi_data2send <= spi_data2send>>1; //shift

   //spi control counter
   always @ (negedge sclk, posedge spi_rst[1])
      if (spi_rst[1])
	spi_counter <= 6'd63;
      else if (spi_start[1])
	spi_counter <= 6'd0;        
      else if (spi_counter != 6'd63)
	spi_counter <= spi_counter + 1'b1;
   
   // spi slave select
   always @ (negedge sclk, posedge spi_rst[1])
      if(spi_rst[1])
        ss <= 1'b1;
      else if (spi_counter == 6'd15)
        ss <= 1'b0;
      else if (spi_counter == 6'd47)
        ss <= 1'b1;
      
   // spi master output slave input
   assign mosi = spi_data2send[0];
   
   //DATA RECEIVED REGISTER
   always @ (posedge sclk)
     if(~ss) //receive miso and shift right
       spi_data_rcvd <= {miso, spi_data_rcvd[`SPI_DATA_W-1:1]};  
   
endmodule
