module spi slave(
	input 				clk,
	input				rst,
	//spi slave signals
	input 				sclk,
	input				ss,
	input				mosi,
	output				miso,

	//signals used in reg_bank
	input		[`DATA_W-1:0] 	data_in,
	output reg	[`DATA_W-1:0] 	data_out,
	output		[`ADDR_W-1:0] 	address,
	output 				we
);
	//signals between spi_fe and spi_protocol
	wire 				ss_pos_edge;
	wire 				ss_neg_edge;
	wire 		[`DATA_W-1:0] 	data_fe_in;
	wire 		[`DATA_W-1:0] 	data_fe_out;


	spi_fe spi_fe (
	       	.clk(clk),
	       	.rst(rst),
	       	.sclk(sclk), 
	       	.ss(ss), 
	       	.mosi(mosi), 
	       	.miso(miso), 
	       	.data_in(data_fe_in),
	       	.data_out(data_fe_out),
	       	.ss_pos_edge(ss_pos_edge),
	       	.ss_neg_edge(ss_neg_edge)
	);


	spi_protocol spi_protocol (
		.clk(clk),
		.rst(rst),
		.data_fe_in(data_fe_out) ,
		.data_in(data_in),
		.ss_pos_edge(ss_pos_edge),
		.ss_neg_edge(ss_neg_edge),
		.data_fe_out(data_fe_in),
		.data_out(data_out),
		.address(address),
		.we(we)
	);

endmodule
