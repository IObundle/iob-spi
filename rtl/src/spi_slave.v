/*****************************************************************************

  Description: SPI slave

  Copyright (C) 2018 IObundle, Lda All rights reserved

******************************************************************************/

`timescale 1ns / 1ps
`include "spi_defines.vh"

module spi_slave(
	input                        clk,
	input                        rst,

	//SPI INTERFACE
	input                        sclk,
	input                        ss,
	input                        mosi,
	output                       miso,

	//CONTROL INTERFACE
	input [`SPI_DATA_W-1:0]      data_in,
	output reg [`SPI_DATA_W-1:0] data_out,
	input [`SPI_ADDR_W-1:0]      address,
	input                        sel,
	input                        read,
	input                        write
);

  
   //CPU SIDE SIGNALS
   reg                           rst_soft;
   reg                           rst_soft_en;
   wire                          rst_int;   

   reg [1:0]                     ctr_ready;

   reg [`SPI_DATA_W-1:0]         ctr_data_rcvd[1:0];

   reg [`SPI_DATA_W-1:0] 	 ctr_data2send;
   reg 				 ctr_data2send_en;

   reg [31:0]                    dummy_reg;
   reg                           dummy_reg_en;


   //SPI SIDE SIGNALS
   
   reg [`SPI_DATA_W-1:0] 	 spi_data_rcvd;
   reg [`SPI_DATA_W-1:0] 	 spi_data2send;
   reg                           spi_ready;
   reg [`SPI_DATA_W-1:0]         spi_ctr_data2send[1:0];
   
   //
   //CONTROLLER SIDE LOGIC
   //

   //combine hard and soft resets   
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



   //
   // ADDRESS DECODER
   //
   
   //write
   always @* begin
      ctr_data2send_en = 1'b0;
      dummy_reg_en = 0;
      rst_soft_en = 1'b0;
  
      case (address)
	`SPI_TX: ctr_data2send_en = sel&write;
	`SPI_SOFT_RST: rst_soft_en = sel&write;
        `DUMMY_REG: dummy_reg_en = sel&write;
	default:;
      endcase
   end

   //read
   always @* begin
      data_out = `SPI_DATA_W'd0;
      if(sel&read)
        case (address)
	  `SPI_READY: data_out = ctr_ready[1] | 0;
	  `SPI_RX: data_out = ctr_data_rcvd[1];
	  `SPI_VERSION: data_out = `SPI_VERSION_STR; 
          `DUMMY_REG: data_out = dummy_reg;
	  default:;
        endcase
   end


   //
   // REGISTERS
   //

   //soft reset self-clearing register
   always @ (posedge clk, posedge rst)
     if (rst)
       rst_soft <= 1'b1;
     else if (rst_soft_en && !rst_soft)
       rst_soft <= 1'b1;
     else
       rst_soft <= 1'b0;

   
   // data to send register 
   always @ (posedge clk, posedge rst_int)
     if (rst_int)
       ctr_data2send <=0;
     else if(ctr_data2send_en)
       ctr_data2send <= data_in;
   
   //dummy register
   always @(posedge clk, posedge rst_int)
     if(rst_int)
       dummy_reg <= 32'b0;  
     else if(dummy_reg_en)
       dummy_reg <= data_in;

   //
   //
   //SPI SIDE LOGIC
   //
   //

   //reset
   reg [1:0] spi_rst;

   //synchronizers

   //reset
   always @(posedge sclk, posedge rst_int)
     if(rst_int)
       spi_rst <= 2'b11;
     else
       spi_rst <= {spi_rst[0], 1'b0};

   //ready register
   reg  ss_reg;
   always @(posedge sclk, posedge spi_rst[1])
     if(spi_rst[1]) begin
        spi_ready <= 1'b1;
        ss_reg <= 1'b1;
     end else begin
        ss_reg <= ss;
        spi_ready <= ss_reg;
     end


   // spi_ctr_data2send synchronizer                    
   always @(posedge sclk, posedge spi_rst[1])
     if(spi_rst[1]) begin
        spi_ctr_data2send[0] <= 0;       
        spi_ctr_data2send[1] <= 0; 
     end else begin                                         
       spi_ctr_data2send[0] <= ctr_data2send;       
       spi_ctr_data2send[1] <= spi_ctr_data2send[0];
     end                                           

   //DATA TO SEND REGISTER
   always @ (negedge sclk, posedge spi_rst[1])
     if(spi_rst[1]) begin
       spi_data2send <= 0;
     end else if (ss)
       spi_data2send <= spi_ctr_data2send[1]; //load
     else
       spi_data2send <= spi_data2send>>1; //shift

   // SPI MASTER INPUT SLAVE OUTPUT
   assign miso = spi_data2send[0];
   
   //DATA RECEIVED SHIFT REGISTER
   always @ (posedge sclk)
     if(~ss)
       spi_data_rcvd <= {mosi, spi_data_rcvd[`SPI_DATA_W-1:1]};

endmodule
