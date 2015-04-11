
`timescale 1ns/1ps
`include "rcntlr_defines.v"

module register_bank (
  input		    clk,
  input  	    rst,
  input             wr,
  input    [`SPI_ADDR_W-1:0] address,     
  input    [`SPI_DATA_W-1:0] data_in,   
//  output [2**`SPI_ADDR_W * `SPI_DATA_W - 1 :0] chip_out,    
  output wire [`SPI_DATA_W-1:0] data_out    
);

reg [`SPI_DATA_W-1:0] my_bank [2**`SPI_ADDR_W-1:0];
integer i;

genvar j;

//generate

//   for (j= 0; j < 2**`SPI_ADDR_W; j=j+1) begin : chip_out_gen
//	assign chip_out[(j+1) * `SPI_DATA_W - 1 -: `SPI_DATA_W] = my_bank[j][`SPI_DATA_W -1 -: `SPI_DATA_W ];

//   end

//endgenerate 

assign data_out = my_bank[address];


always @ (posedge clk, posedge rst) begin
   if (rst == 1'b1) begin
      for (i=0 ; i< 2**`SPI_ADDR_W ; i=i+1) begin
        my_bank[i] <= `SPI_ADDR_W'b0;
      end
    end
   else if (wr == 1'b1) begin
      my_bank[address] <= data_in;
   end

end


endmodule
