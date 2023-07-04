`timescale 1ns / 1ps
`include "iob_lib.vh"
`include "interconnect.vh"
`include "iob_spi_fl.vh"

`ifdef FLASH_ADDR_W
`define FLASH_CACHE_ADDR_W `FLASH_ADDR_W
`else
`define FLASH_CACHE_ADDR_W 24
`endif

module iob_spi_master #(
    parameter ADDR_W  = `FL_ADDR_W,
    parameter DATA_W  = `DATA_W,
    parameter WDATA_W = `FL_WDATA_W
) (

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
  reg rst_int;
  always @* begin
    rst_int = rst | FL_RESET;
  end

  //Ready signal from flash controller
  wire readyflash_int;

  assign FL_READY = readyflash_int;

  //Cache interface connection
  wire [DATA_W-1:0] dataout_int;
  assign FL_DATAOUT = dataout_int;
  wire [32-1:0] address_int;
  wire valid_int;
`ifdef RUN_FLASH
  assign rdata_cache = dataout_int;
  wire cache_read_req_en;
  assign cache_read_req_en = valid_cache&(~|wstrb_cache);
  assign address_int = cache_read_req_en ? {{(DATA_W-`FLASH_CACHE_ADDR_W){1'b0}},address_cache} : FL_ADDRESS;
  assign valid_int = cache_read_req_en?valid_cache:FL_VALIDFLG;

  //Cache Ready Output
  reg cache_ready_en;
  assign ready_cache = cache_ready_en?readyflash_int:1'b0;
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
  assign address_int = FL_ADDRESS;
  assign valid_int = FL_VALIDFLG;
`endif

  //Instantiate core
  spi_master_fl #(
      .CLKS_PER_HALF_SCLK(2)
  ) fl_spi0 (
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
      .dtr_en(FL_COMMANDTP[20]),
      .fourbyteaddr_on(FL_COMMANDTP[21]),
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