`timescale 1ns / 1ps
`include "spi_defines.vh"

module spi_top (
		input 			 rst, 
		input 			 clk,
		input 			 sclk,

		//spi master control
		input [`SPI_ADDR_W-1:0]  m_address,
		input [`SPI_DATA_W-1:0]  m_data_in,
		input 			 m_sel,
		input 			 m_we,
		output [`SPI_DATA_W-1:0] m_data_out,
		output 			 m_interrupt,

		//spi slave control
		input [`SPI_ADDR_W-1:0]  s_address, 
		input 			 s_sel,
		input 			 s_we, 
		output [`SPI_DATA_W-1:0] s_data_out,
		input [`SPI_DATA_W-1:0]  s_data_in, 
		output			 s_interrupt
		);
	  
   //spi signals
   wire 				 miso;
   wire 				 mosi;
   wire 				 ss;   
   

   // Instantiate the Units Under Test (UUTs)
   spi_master spi_m (
		     .clk		(clk),
		     .rst		(rst),
		     
		     // SPI 
		     .ss		(ss),
		     .mosi		(mosi),
		     .sclk		(sclk),
		     .miso		(miso),
		     
		     // CONTROL
		     .data_in		(m_data_in[`SPI_DATA_W-1:0]),
		     .address		(m_address[`SPI_ADDR_W-1:0]),
		     .data_out		(m_data_out[`SPI_DATA_W-1:0]),
		     .interrupt		(m_interrupt),
		     .we		(m_we),
		     .sel		(m_sel));
   
   spi_slave spi_s (
		    .clk		(clk),
		    .rst		(rst),

		    // SPI 
		    .miso		(miso),
		    .sclk		(sclk),
		    .ss			(ss),
		    .mosi		(mosi),
		    
		    // CONTROL
		    .data_out		(s_data_out[`SPI_DATA_W-1:0]),
		    .interrupt		(s_interrupt),
		    .data_in		(s_data_in[`SPI_DATA_W-1:0]),
		    .address		(s_address[`SPI_ADDR_W-1:0]),
		    .we			(s_we),
		    .sel		(s_sel));

 
endmodule

