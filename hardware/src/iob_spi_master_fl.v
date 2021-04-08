`timescale 1ns/1ps
`include "iob_lib.vh"
`include "interconnect.vh"
`include "iob_spi_fl.vh"

module iob_spi_master_fl
#(
	parameter ADDR_W = `FL_ADDR_W,
	parameter DATA_W = `DATA_W,
	parameter WDATA_W = `FL_WDATA_W
)
(
	
`include "cpu_nat_s_if.v"
`include "flash_if.v"
`include "gen_if.v"
);


	//Software Accessible Registers
`include "SPIsw_reg.v"
`include "SPIsw_reg_gen.v"

	//Hard or Soft Reset
	`SIGNAL(rst_int, 1)
	`COMB rst_int = rst | FL_RESET;
	
	//Ready signal from flash controller
	`SIGNAL(ready_int, 1)
	`SIGNAL2OUT(ready, ready_int)

	//Instantiate core
	spi_master_fl 
	#(
		.CLKS_PER_HALF_SCLK(2)
	)
	fl_spi0
	(
		.data_in(FL_DATAIN),
		.data_out(FL_DATAOUT),
		.address(FL_ADDRESS),
		.command(FL_COMMAND[7:0]),
		.ndata_bits(FL_COMMAND[14:8]),
		.dummy_cycles(FL_COMMAND[19:16]),
        .frame_struct(FL_COMMAND[29:20]),
        .xipbit_en(FL_COMMAND[31:30]),
		.validflag(FL_VALIDFLG),
		.commtype(FL_COMMANDTP),
		.validflag_out(FL_VALIDFLGOUT),
		.tready(ready_int),

		.clk(clk),
		.rst(rst_int),
		//Not sw registers
		.sclk(SCLK),
		.ss(SS),
		.mosi_dq0(MOSI),
		.wp_n_dq2(WP_N),
		.hold_n_dq3(HOLD_N),
		.miso_dq1(MISO)
	);


endmodule
