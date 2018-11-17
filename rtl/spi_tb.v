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
   spi_master spi_m (
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
      m_sel = 0;
      m_we = 0;
      
      // POLLING TEST 

      // write command word to send
      #(20*clk_per+1) m_address = `SPI_TX;
      m_data_in = 32'hF0F0F0F0;
      m_sel = 1;
      m_we = 1;
      #clk_per m_we = 0;
      m_sel = 0;

      // wait spi master to finish
      #clk_per m_address = `SPI_READY;
      m_sel = 1;
      while(m_data_out == 0) 
	#clk_per m_address = `SPI_READY;
      m_sel = 0;

      // write nop to be sent next
      #(1000*clk_per) m_address = `SPI_TX;
      m_data_in = 32'h0;                
      m_sel = 1;
      m_we = 1;
      #clk_per m_we = 0;
      m_sel = 0;
      
      // poll SPI_READY until word received
      #clk_per m_address = `SPI_READY;
      m_sel = 1;
      while(m_data_out == 0) 
	#clk_per m_address = `SPI_READY;
      m_sel = 0;


      // read word, compare with expected and clear ready
      #clk_per m_address = `SPI_RX;
      m_sel = 1;
      #clk_per;
      if(m_data_out != 32'hF0F0F0F0) begin
	 $display("Polling test failed");
	 $finish;
      end
      m_sel = 0;
      

      // INTERRUPT TEST 

      // enable interrupt
      #clk_per m_address = `SPI_INTRRPT_EN;
      m_data_in = 32'h1;
      m_sel = 1;
      m_we = 1;
      #clk_per m_we = 0;
      m_sel = 0;
      

      // write word to send next
      #(20*clk_per+1) m_address = `SPI_TX;
      m_data_in = 32'hABABABAB;
      m_sel = 1;
      m_we = 1;
      #clk_per m_we = 0;
      m_sel = 0;
      

      // wait interrupt on word sent
      while(~m_interrupt)
	#clk_per;
      

      // read RX register to clear interrupt
      #clk_per m_address = `SPI_RX;
      m_sel = 1;
      #clk_per m_sel = 0;
 
      // write nop to be sent next
      #(1000*clk_per) m_address = `SPI_TX;
      m_data_in = 32'h0;                     //send nop
      m_sel = 1;
      m_we = 1;
      #clk_per m_we = 0;
      m_sel = 0;
 
     // wait interrupt on nop sent
      while(~m_interrupt)
	#clk_per;

      // read word in RX register
      #clk_per m_address = `SPI_RX;
      m_sel = 1;
      #clk_per;
      if(m_data_out != 32'hABABABAB) begin 
	 $display("Interrupt test failed");
	 $finish;
      end
      m_sel = 0;

      $display("Test Passed!");
      $finish;
      
   end


   //
   // SLAVE PROCESS
   //
   initial begin

      s_sel = 0;
      s_we = 0;

      //
      // POLLING TEST 
      //
      
      // poll SPI_READY address until word received
      #clk_per s_sel = 1;
      s_address = `SPI_READY;
      while(s_data_out == 0) 
	#clk_per s_address = `SPI_READY;
      s_sel = 0;

      // read word
      #clk_per s_address = `SPI_RX;
      s_sel = 1;
      #clk_per s_data_in = s_data_out;
      s_sel = 0;
   
      // write word to send it back to master 
      #(20*clk_per+1) s_address = `SPI_TX;
      s_sel = 1;
      s_we = 1;
      #clk_per s_we = 0;
      s_sel = 0;
      s_we = 0;

  
      // poll SPI_READY address until word sent
      #clk_per s_sel = 1;
      s_address = `SPI_READY;
      while(s_data_out == 0) 
	#clk_per s_address = `SPI_READY;
      s_sel = 0;
    
      // read nop word to clear ready
      #clk_per s_address = `SPI_RX;
      s_sel = 1;
      #clk_per s_sel = 0;


      //
      // INTERRUPT TEST 
      //
      
      // enable interrupt
      #clk_per s_address = `SPI_INTRRPT_EN;
      s_data_in = 32'h1;
      s_sel = 1;
      s_we = 1;
      #clk_per s_sel = 0;
      s_we = 0;

      // wait for interrupt until data is received
      while(~s_interrupt)
 	#clk_per;
     
      // read word and clear interrupt
      #clk_per s_address = `SPI_RX;
      s_sel = 1;
      s_data_in = s_data_out;
      #clk_per s_sel = 0;

     // write word to send it back to master
      #(20*clk_per+1) s_address = `SPI_TX;
      s_data_in = s_data_out;
      s_sel = 1;
      s_we = 1;
      #clk_per s_we = 0;
      s_sel = 0;
 
      // wait for interrupt on word is sent and nop received
      while(~s_interrupt)
  	#clk_per;

       // read nop to clear interrupt 
      #clk_per s_address = `SPI_RX;
      s_sel = 1;
      #clk_per s_sel = 0;

  end

   
   //
   // CLOCKS 
   //
   
   always
     #(sclk_per/2) sclk = ~sclk;
   
   always
     #(clk_per/2) clk = ~clk;
   

endmodule

