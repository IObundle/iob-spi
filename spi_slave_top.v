module spi slave top(
	input 				clk,
	input				rst,
	//spi slave signals
	input 				sclk,
	input				ss,
	input				mosi,
	output				miso,

    input ext_req,
    input ext_rnw,
    input [`CTRL_REGF_ADDR_W-1:0] ext_addr,
    input [`DATA_W-1:0] ext_data_in,
    output [`DATA_W-1:0] ext_data_out,

    input int_req,
    input int_rnw,
    input [`CTRL_REGF_ADDR_W-1:0] int_addr,
    input [`DATA_W-1:0] int_data_in,
    output [`DATA_W-1:0] int_data_out
);

	//signals used in reg_bank
	wire		[`DATA_W-1:0] 	data_in;
	wire		[`DATA_W-1:0] 	data_out;
	wire		[`ADDR_W-1:0] 	address;
	wire 				we;

	spi_slave spi_slave (
	       	.clk(clk),
	       	.rst(rst),
	       	.sclk(sclk), 
	       	.ss(ss), 
	       	.mosi(mosi), 
	       	.miso(miso), 
	       	.data_in(data_in),
	       	.data_out(data_out),
		.address(address),
		.we(we)
	);

 	xctr_regf ctr_regf(
    		.clk(clk),
    		.ext_req(ext_req),
    		.ext_rnw(ext_rnw),
    		.ext_addr(ext_addr),
    		.ext_data_in(ext_data_in),
    		.ext_data_out(ext_data_out),

    		.int_req(int_req),
    		.int_rnw(int_rnw),
    		.int_addr(int_addr),
    		.int_data_in(int_data_in),
    		.int_data_out(int_data_out)
    	);

endmodule
