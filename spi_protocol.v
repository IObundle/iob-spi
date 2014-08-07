`include "spi-defines.v"

module spi_protocol (
	input 						clk,
	input						rst,
	input 		[`DATA_W-1:0]	data_fe_in ,
	input		[`DATA_W-1:0]	data_in,
	input 						ss_pos_edge,
	input 						ss_neg_edge,
	output 		[`DATA_W-1:0]	data_fe_out,
	output reg	[`DATA_W-1:0]	data_out,
	output 		[`ADDR_W-1:0]	address,
	output 						we
);

	reg 		[1:0] state;
	reg 		rnw;

	assign we = state[0] & state[1]; //?

	assign data_fe_out = data_in;

	assign rnw = data_fe_in[`DATA_W-1 -:1]; //?

	always @(posedge clk, posedge rst) begin //states
			if(rst) begin
				state <= 2'b0;
				rnw <= 1'b0;
				we <= 1'b0;
				data_fe_out <= 0;
				data_out <= 0;
				address <= 0;
				
			end else
				case (state)
					2'b00: begin //idle
							if(ss_pos_edge) begin
								state <=	2'b01;
								address <= data_fe_in[`ADDR_W-1:0];
							end
					end
					2'b01: begin //read config word						
								if(ss_pos_edge) begin
									state <= 2'b10;
									if(~rnw)
										data_out <= data_fe_in;									
								end 
					end
					2'b10: begin //data read /data write
								if(ss_neg_edge)
									state <= 2'b00;
					end		
				endcase
      		end

endmodule

