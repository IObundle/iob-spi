`timescale 1ns/1ps
`include "iob_lib.vh"
`include "interconnect.vh"
`include "iob_spi_fl.vh"
//check later
`define FLASH_CACHE_ADDR_W 24

module iob_spi_master_fl
#(
	parameter ADDR_W = `FL_ADDR_W,
	parameter DATA_W = `DATA_W,
	parameter WDATA_W = `FL_WDATA_W
)
(
	
`include "cpu_nat_s_if.v"
`ifdef RUN_FLASH
`include "cpu_nat_s_cache_if.v"
`endif
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
	`SIGNAL(readyflash_int, 1)
    
    `SIGNAL2OUT(FL_READY, readyflash_int)

    //Cache interface connection
    `SIGNAL_OUT(dataout_int, DATA_W)
    `SIGNAL2OUT(FL_DATAOUT, dataout_int)
    `SIGNAL_OUT(address_int, 32)
    `SIGNAL_OUT(valid_int, 1)
`ifdef RUN_FLASH
    `SIGNAL2OUT(rdata_cache, dataout_int) 
    `SIGNAL_OUT(cache_read_req_en, 1)
    `SIGNAL2OUT(cache_read_req_en, valid_cache & (~|wstrb_cache))
    assign address_int = cache_read_req_en ? {{(32-`FLASH_CACHE_ADDR_W){1'b0}},address_cache} : FL_ADDRESS;
    `SIGNAL2OUT(valid_int, cache_read_req_en ? valid_cache : FL_VALIDFLG)
    
    //Cache Ready Output
    `SIGNAL(cache_ready_en, 1)
    `SIGNAL2OUT(ready_cache, cache_ready_en ? readyflash_int : 1'b0)
    always @(posedge clk, posedge rst) begin
       if (rst) cache_ready_en <= 1'b0; 
       else begin
           case (cache_ready_en)
               1'b0: begin
                    if (valid_cache) cache_ready_en <= 1'b1;
               end
               1'b1: begin
                    if (readyflash_int) cache_ready_en <= 1'b0;
               end
               default: cache_ready_en <= 1'b0;
           endcase
       end
    end
`else
    `SIGNAL2OUT(address_int, FL_ADDRESS)
    `SIGNAL2OUT(valid_int, FL_VALIDFLG)
`endif

	//Instantiate core
	spi_master_fl 
	#(
		.CLKS_PER_HALF_SCLK(2)
	)
	fl_spi0
	(
		.data_in(FL_DATAIN),
		.data_out(dataout_int),
		.address(address_int),
		.command(FL_COMMAND[7:0]),
		.ndata_bits(FL_COMMAND[14:8]),
		.dummy_cycles(FL_COMMAND[19:16]),
        .frame_struct(FL_COMMAND[29:20]),
        .xipbit_en(FL_COMMAND[31:30]),
		.validflag(valid_int),
		.commtype(FL_COMMANDTP[2:0]),
        .spimode(FL_COMMANDTP[31:30]),
        .manualframe_en(FL_COMMANDTP[29]),
        .fourbyteaddr_on(FL_COMMAND[15]),
		.validflag_out(FL_VALIDFLGOUT),
		.tready(readyflash_int),
        
		.clk(clk),
		.rst(rst_int),

        //Flash Memory interface
		.sclk(SCLK),
		.ss(SS),
		.mosi_dq0(MOSI),
		.wp_n_dq2(WP_N),
		.hold_n_dq3(HOLD_N),
		.miso_dq1(MISO)

	);


endmodule
