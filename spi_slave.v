/////////////////////////////////////////////////////////////////////////////
////                                                                     ////        
//// Memory with interface SPI				                 ////
////                                                                     ////
////                                                                     ////
//// Author(s):  Carlos Rodrigues		        		 ////
////	   	 carlosaarodrigues@inesc-id.pt                           ////
////                                                                     ////
//// Downloaded from:     					         ////
////  https://github.com/jjts/orpsoc-cores/tree/master/cores/memory_spi  ////
/////////////////////////////////////////////////////////////////////////////
////                                                                     ////
//// Copyright (C) 2013 Carlos Rodigues                        		 ////
////                    carlosaarodrigues@inesc-id.pt                    ////
////                                                                     ////
////  This Source Code Form is subject to the terms of the        	 ////
////  Open Hardware Description License, v. 1.0. If a copy        	 ////
////  of the OHDL was not distributed with this file, You        	 ////
////  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt            ////
////                                                                     ////
/////////////////////////////////////////////////////////////////////////////



module spi_slave (
  input		    clk,
  input  	    rst,
  // SPI port
  input             sclk_in,      // serial clock output
  input  wire 	    ss,      	// slave select (active low)
  input  wire       mosi,     // MasterOut SlaveIN
	output wire rst_led,
  output wire HDR1_2,
  output reg        miso      // MasterIn SlaveOut
);

   reg [1:0] 	    state;
   reg [7:0] 	    word;
   reg [3:0] 	    word_cnt;
   reg [3:0] 	    word_cnt_s;
   
   wire		sclk;
   wire		word_done;

   reg [7:0] 	data_w;
   reg [7:0] 	data_r;
   wire [7:0] 	reg_out;
   
      
   reg   	wr;
   reg 		en2;
	reg		en1;
   reg [6:0] 	address;
   reg [6:0] 	address_in;
	
	reg [7:0] test_aux;

   reg [2:0] 	d;
	reg [7:0]	data_r_aux;
	
   wire 	postrig, negtrig, enbl;
  
	assign enbl = (en1 ^ en2) & ~ss;
	
	assign rst_led = ~rst;
	
	assign HDR1_2 = test_aux[7];
	
   assign word_done = ~|word_cnt;
	
	BUFG bufg_sclk(.I(sclk_in), .O (sclk));
	
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

   always @(posedge clk) begin //states
      
		if(ss) begin         
			state <= 2'b10;
			wr <= 1'b0;
			en1 <= 1'b0;
			address <= 7'd0;
		end 
      
		else begin
	 
			case (state)
	   
			2'b10:  //standby
				if (word_done & postrig & ~enbl) begin
					state[1] <= 1'b0;
					state[0] <= word[7];
					address <= word[6:0];
				end
	   
			2'b00: //write
				if (word_done & postrig) begin
					wr <= 1'b1;
					address_in <= address;
					data_w <= word;
					state <= 2'b10;
				end
	   
			2'b01: //adress read
				if (negtrig) begin
					wr <= 1'b0;
					address_in <= address;
					state <= 2'b11;
					en1 <= ~en2;//set enbl high
				end
			2'b11:begin //data read
				state <= 2'b10;
				data_r <= reg_out;
				end
			endcase	      
		end 
	end 
      
	always @(posedge sclk) begin //read from mosi
		if(ss) begin
			word_cnt <= 4'b1000;
			word <= 8'h00;
		end else begin
			word  <= {word[6:0],mosi};
			word_cnt <= word_cnt - 1'b1;
		if(word_done)
			word_cnt <= 4'b0111;
		end

	end
   
	always @(posedge sclk) begin //write to miso
		if (ss) begin
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
