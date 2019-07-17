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
	input                        write,
	output                       interrupt
);

  
   //CPU SIDE SIGNALS
   reg                           rst_soft;
   wire                          rst_int;   

   reg 				 ctr_ready;
   reg 				 ctr_ready_clr;
   reg [2:0]                     ctr_ss;

   reg [`SPI_DATA_W-1:0] 	 ctr_data2send;
   reg 				 ctr_data2send_en;
   reg 				 ctr_interrupt_en;
   reg 				 ctr_interrupt_en_en;

   reg [31:0]                    dummy_reg;
   reg                           dummy_reg_en;

   //SPI SIDE SIGNALS
   reg [`SPI_DATA_W-1:0] 	 spi_data_rcvd;
   reg [`SPI_DATA_W-1:0] 	 spi_data2send;
   
   reg [`SPI_DATA_W-1:0]         ctr_data2send_spi[1:0];
   
   //
   //CONTROLLER SIDE LOGIC
   //
   
   //
   // ADDRESS DECODER
   //
   
   assign rst_int = rst | rst_soft;


   always @* begin
      data_out = `SPI_DATA_W'd0;
      ctr_data2send_en = 1'b0;
      ctr_ready_clr = 1'b0;
      ctr_interrupt_en_en = 1'b0;
      dummy_reg_en = 0;
      rst_soft = 1'b0;
  
      case (address)
	`SPI_INTRRPT_EN: ctr_interrupt_en_en = sel&write;
	`SPI_READY: data_out = { {`SPI_DATA_W-1{1'b0}}, ctr_ready}; 
	`SPI_TX: ctr_data2send_en = sel&write;
	`SPI_RX: begin 
	   data_out = spi_data_rcvd;
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

  
   // READY REGISTER
   always @ (posedge clk, posedge rst_int)
     if (rst_int)
       ctr_ready <= 1'b0;
     else if (ctr_ready_clr)
       ctr_ready <= 1'b0;
     else if (!ctr_ss[2] & ctr_ss[1])
       ctr_ready <= 1'b1;
     
   // DATA TO SEND REGISTER 
   always @ (posedge clk)
     if(ctr_data2send_en)
       ctr_data2send <= data_in;
   
   // INTERRUPT ENABLE REG
    always @ (posedge clk)
      if(rst_int)
	ctr_interrupt_en <= 1'b0;
      else if(ctr_interrupt_en_en)
	ctr_interrupt_en <= data_in[0];

   assign interrupt = ctr_interrupt_en & ctr_ready;

   //dummy register
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
   //SPI SIDE LOGIC
   //
   //
   // ctr_data2send synchronizer                    
   always @(posedge sclk)                           
     begin                                         
       ctr_data2send_spi[0] <= ctr_data2send;       
       ctr_data2send_spi[1] <= ctr_data2send_spi[0];
     end                                           

   //DATA TO SEND REGISTER
   always @ (negedge sclk)
     if (ss)
       spi_data2send <= ctr_data2send_spi[1]; // false path, but sync added anyway
     else
       spi_data2send <= spi_data2send>>1;

   // SPI MASTER INPUT SLAVE OUTPUT
   assign miso = spi_data2send[0];
   
   //DATA RECEIVED SHIFT REGISTER
   always @ (posedge sclk)
     if(~ss)
       spi_data_rcvd <= {mosi, spi_data_rcvd[`SPI_DATA_W-1:1]};

endmodule
