/* ****************************************************************************
  This Source Code Form is subject to the terms of the
  Open Hardware Description License, v. 1.0. If a copy
  of the OHDL was not distributed with this file, You
  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

  Description: SPI 8-bit front end

   Copyright (C) 2014 Authors

  Author(s): Jose T. de Sousa <jose.t.de.sousa@gmail.com>


***************************************************************************** */



module spi_fe (
	       input 		    clk,
	       input 		    rst,
		  // SPI port
	       input 		    sclk_in, //serial clock
	       input wire 	    ss, // slave select (active low)
	       input wire 	    mosi, // MasterOut SlaveIN
	       output reg 	    miso, // MasterIn SlaveOut

	       //parallel interface
	       input [`DATA_W-1:0]  data_in,
	       output [`DATA_W-1:0] data_out,
	       output data_out_valid
		  );

   reg [1:0] 		      state;
   reg [7:0] 		      word;
   reg [3:0] 		      word_cnt;
   
   wire 		      sclk;
   wire 		      word_done;

   wire 		      postrig, negtrig, enbl;
   

   
   assign word_done = ~|word_cnt;
   
   //BUFG bufg_sclk(.I(sclk_in), .O (sclk));
   assign sclk = sclk_in;
   
   assign postrig = ~d[2] & d[1];     //posedge detect
   assign negtrig = d[2] & ~d[1];     //negedge detect 
   

   always @(posedge clk) begin //sclk edge detect

      if(ss)
	d <= 3'b000;
      else begin
	 d[2:1] <= d[1:0];
	 d[0] <= sclk;
      end 
   end 

   always @(posedge sclk) begin
      
   

  
   always @(posedge sclk) begin //read from mosi
      if(re) 
	 word  <= {word[6:0],mosi};
	 word_cnt <= word_cnt - 1'b1;
      end else begin
	 word_cnt <= 4'd7;
	 word <= 8'h00;
      end
   end
   
   always @(posedge sclk) begin //write to miso
      if (we) begin
	 word_cnt_s <= 4'b1000;
	 data_r_aux <= 8'b10000000;
	 en2 <= 1'b0;
	 miso <= 1'b0;
      end
      else if(enbl) begin
	 miso  <= |(data_r & data_r_aux);
	 data_r_aux <= {data_r_aux[0] , data_r_aux[7:1]}; //rotate right
	 word_cnt_s <= word_cnt_s - 1'b1;
	 if(word_cnt_s == 4'b0000) begin
	    word_cnt_s <= 4'b1000;
	    data_r_aux <= 8'b10000000;
	    en2 <= en1; // set enbl low
	 end 
      end
   end
   
   always @(posedge clk) begin
      if(rst)
	test_aux <= 8'b00000000;
      else
	test_aux <= test_aux + 8'b00000001;
   end
   
   

   
   
   
   register_bank  register_bank (
				 .clk (clk),
				 .rst (rst),
				 .wr (wr),
				 .address (address_in),
				 .data_in (data_w),
				 .data_out (reg_out)
				 );
   
   
   
endmodule 
