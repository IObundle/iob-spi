`timescale 1ns / 1ps

module sclk_gen
#(
    parameter CLKS_PER_HALF_SCLK=2,
    parameter CPOL=1,
    parameter CPHA=1
)
(
    input clk,
    input rst,

    input [8:0] sclk_edges,
    input sclk_en,
    input op_start,
    output reg op_done,
    output reg sclk_leadedge,
    output reg sclk_trailedge,
    output reg sclk_int
    
);

	reg [$clog2(CLKS_PER_HALF_SCLK*2)-1:0]	clk_counter;
    reg [8:0] sclk_edges_counter = 0;

    wire w_CPOL;
	wire w_CPHA;

	assign w_CPOL = (CPOL==1);
	assign w_CPHA = (CPHA==1);

	always @(posedge clk, posedge rst) begin
		if (rst) begin
			sclk_leadedge <= 1'b0;
			sclk_trailedge <= 1'b0;
			sclk_int <= w_CPOL;
			clk_counter <= 0; 
			sclk_edges_counter <= 9'h0;
			op_done <= 1'b0;
		end else begin
			if (op_start) begin
					if(sclk_edges_counter > 0) begin
						if (clk_counter == CLKS_PER_HALF_SCLK-1) begin
							sclk_leadedge <= 1'b1;
							sclk_trailedge <= 1'b0;
							sclk_edges_counter <= sclk_edges_counter - 1'b1;
							if (sclk_en) sclk_int <= ~sclk_int;
							clk_counter <= clk_counter + 1'b1;
						end else if (clk_counter == CLKS_PER_HALF_SCLK*2-1) begin
							sclk_leadedge <= 1'b0;
							sclk_trailedge <= 1'b1;
							sclk_edges_counter <= sclk_edges_counter - 1'b1;
							if (sclk_en) sclk_int <= ~sclk_int;
							clk_counter <= clk_counter + 1'b1;
						end else begin
							sclk_leadedge <= 1'b0;
							sclk_trailedge <= 1'b0;
							clk_counter <= clk_counter + 1'b1;
						end
					end else begin
						op_done <= 1'b1;
						sclk_trailedge <= 1'b0;
						sclk_leadedge <= 1'b0;
					end
			end else begin
				sclk_int <= w_CPOL; //Initial sclk polarity
				sclk_leadedge <= 1'b0;
				sclk_trailedge <= 1'b0;
				clk_counter <= 0; 
				op_done <= 1'b0;
				sclk_edges_counter <= sclk_edges;
			end
		end
	end


endmodule
