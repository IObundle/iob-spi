
`timescale 1ns/1ps
`include "rcntlr_defines.v"

module register_bank (
  input		    clk,
  input  	    rst,
  input             wr,
  input    [`LOG_N_REGISTERS-1:0] address,     
  input    [`DATA_WIDTH-1:0] data_in,   
  output [2**`LOG_N_REGISTERS * `DATA_WIDTH - 1 :0] chip_out,    
  output wire [`DATA_WIDTH-1:0] data_out    
);

reg [`DATA_WIDTH-1:0] my_bank [2**`LOG_N_REGISTERS-1:0];
integer i;

genvar j;

generate

   for (j= 0; j < 2**`LOG_N_REGISTERS; j=j+1) begin : chip_out_gen
	assign chip_out[(j+1) * `DATA_WIDTH - 1 -: `DATA_WIDTH] = my_bank[j][`DATA_WIDTH -1 -: `DATA_WIDTH ];

   end

endgenerate 

assign data_out = my_bank[address];


always @ (posedge clk, posedge rst) begin
   if (rst == 1'b1) begin
      for (i=0 ; i< 2**`LOG_N_REGISTERS ; i=i+1) begin
        my_bank[i] <= `DATA_WIDTH'b0;
      end
    end
   else if (wr == 1'b1) begin
      my_bank[address] <= data_in;
   end

end 


endmodule
