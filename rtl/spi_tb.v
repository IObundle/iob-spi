`timescale 1ns / 1ps
`include "spi_defines.vh"

module spi_master_tb;

   parameter sclk_per= 39;
   parameter clk_per= 10;
   
   reg 		rst;
   reg 		clk;
   
   //spi signals
   reg 			 sclk;
   wire 		 miso;
   wire 		 mosi;
   wire 		 ss;   
   

   //spi master control
   reg [`SPI_ADDR_W-1:0] m_address;
   reg [`SPI_DATA_W-1:0] m_data_in;
   reg 			 m_sel;
   reg 			 m_we;
   wire [`SPI_DATA_W-1:0] m_data_out;
   wire 		  m_interrupt;

   //spi slave control
   reg [`SPI_ADDR_W-1:0] s_address;		
   reg 			  s_sel;
   reg 			  s_we;			
   wire [`SPI_DATA_W-1:0] s_data_out;
   reg [`SPI_DATA_W-1:0]  s_data_in; 
   wire 		  s_interrupt;		


   // Instantiate the Units Under Test (UUTs)
   spi_master uut (
		   .clk			(clk),
		   .rst			(rst),

		    // SPI 
		   .ss			(ss),
		   .mosi		(mosi),
		   .sclk		(sclk),
		   .miso		(miso),

		    // CONTROL
		   .data_in		(m_data_in[`SPI_DATA_W-1:0]),
		   .address		(m_address[`SPI_ADDR_W-1:0]),
		   .data_out		(m_data_out[`SPI_DATA_W-1:0]),
		   .interrupt		(m_interrupt),
		   .we			(m_we),
		   .sel			(m_sel));
   
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

 
   // general process  
   initial begin
      $dumpfile("spi_tb.vcd");
      $dumpvars();

      // assert clocks and reset
      rst = 1;
      clk = 1;
      sclk = 1;

      // deassert reset
      #(2*clk_per+1) rst = 0;
      

   end
   

   //
   // MASTER PROCESS
   //

   initial begin

      // POLLING TEST 

      // write command word to send
      #(20*clk_per+1) m_address = `SPI_TX;
      m_data_in = 32'hF0F0F0F0;
      m_sel = 1;
      m_we = 1;
      #clk_per m_we = 0;
      m_sel = 0;
      
      // start spi master to send command word
      #(20*clk_per) m_address = `SPI_START;
      m_sel = 1;
      m_we = 1;
      #clk_per m_we = 0;
      m_sel = 0;

      // wait spi master to finish
      #clk_per m_address = `SPI_READY;
      while(m_data_out == 0) 
	#clk_per m_address = `SPI_READY;

      // start spi master later to read response word
      #(1000*clk_per) m_address = `SPI_START;
      m_sel = 1;
      m_we = 1;
      #clk_per m_we = 0;
      m_sel = 0;
      
      // wait spi master to finish
      #clk_per m_address = `SPI_READY;
      while(m_data_out == 0) 
	#clk_per m_address = `SPI_READY;


      // read word in RX register
      #clk_per m_address = `SPI_RX;

      if(m_data_out != 32'hF0F0F0F)
	$display("Polling test failed");
      

      // INTERRUPT TEST 

      // write command word to send
      #(20*clk_per+1) m_address = `SPI_TX;
      m_data_in = 32'hF0F0F0F0;
      m_sel = 1;
      m_we = 1;
      #clk_per m_we = 0;
      m_sel = 0;
      
      // start spi master to send command word
      #(20*clk_per) m_address = `SPI_START;
      m_sel = 1;
      m_we = 1;
      #clk_per m_we = 0;
      m_sel = 0;

      // wait spi master to finish
      #clk_per m_address = `SPI_READY;
      while(m_interrupt == 0) 
	#clk_per m_address = `SPI_READY;


      // start spi master much later to read response word
      #(1000*clk_per) m_address = `SPI_START;
      m_sel = 1;
      m_we = 1;
      #clk_per m_we = 0;
      m_sel = 0;
      
      // wait spi master to finish
      #clk_per m_address = `SPI_READY;
      while(m_data_out == 0) 
	#clk_per m_address = `SPI_READY;


      // read word in RX register
      #clk_per m_address = `SPI_RX;

      if(m_data_out != 32'hF0F0F0F)
	$display("Interrupt test failed");

      $finish;
      
   end


   //
   // SLAVE PROCESS
   //
   initial begin


      // POLLING TEST 

      // wait spi slave to become ready after receiving data
      #clk_per s_sel = 1;
      s_address = `SPI_READY;
      while(s_data_out == 0) 
	#clk_per s_address = `SPI_READY;

      #clk_per s_address = `SPI_RX;
      #clk_per s_data_in = s_data_out;
      #clk_per s_sel = 0;
            
      // write response word to send
      #(20*clk_per+1) m_address = `SPI_TX;
      s_sel = 1;
      s_we = 1;
      #clk_per m_we = 0;
      s_sel = 0;

      
      // INTERRUPT TEST 

      // wait spi slave to become ready after receiving data
      #clk_per s_sel = 1;
      while(s_interrupt == 0) 
	#clk_per s_address = `SPI_RX;
      #clk_per s_sel = 0;

      // write response word to send
      #(20*clk_per+1) m_address = `SPI_TX;
      s_data_in = s_data_out;
      s_sel = 1;
      s_we = 1;
      #clk_per m_we = 0;
      s_sel = 0;

   end

   
   //
   // CLOCKS 
   //
   
   always
     #(sclk_per/2) sclk = ~sclk;
   
   always
     #(clk_per/2) clk = ~clk;
   

endmodule

