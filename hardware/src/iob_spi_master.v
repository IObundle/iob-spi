`timescale 1ns / 1ps

`include "iob_spi_conf.vh"
`include "iob_spi_swreg_def.vh"

`ifdef FLASH_ADDR_W
`define FLASH_CACHE_ADDR_W `FLASH_ADDR_W
`else
`define FLASH_CACHE_ADDR_W 24
`endif

module iob_spi_master #(
    `include "iob_spi_params.vs"
) (
    `include "iob_spi_io.vs"
);

  `include "iob_wire.vs"
  wire              iob_ready_nxt_o;
  wire              iob_rvalid_nxt_o;

  wire              avalid_int;
  wire [    32-1:0] address_int;
  wire [DATA_W-1:0] dataout_int;
  //Ready signal from flash controller
  wire              readyflash_int;
  //Hard or Soft Reset
  reg               rst_int;

  wire              FL_RESET;
  wire [      31:0] FL_DATAIN;
  wire [      31:0] FL_ADDRESS;
  wire [      31:0] FL_COMMAND;
  wire [      31:0] FL_COMMANDTP;
  wire              FL_VALIDFLG;
  wire              FL_READY;
  wire [      31:0] FL_DATAOUT;

  //Software Accessible Registers
  `include "iob_spi_swreg_inst.vs"

  always @* begin
    rst_int = arst_i | FL_RESET;
  end

  assign FL_READY = readyflash_int;

  //Cache interface connection
  assign FL_DATAOUT = dataout_int;

  assign iob_avalid = iob_avalid_i;
  assign iob_addr = iob_addr_i;
  assign iob_wdata = iob_wdata_i;
  assign iob_wstrb = iob_wstrb_i;
  assign iob_rvalid_o = iob_rvalid;
  assign iob_rdata_o = iob_rdata;
  assign iob_ready_o = iob_ready;

`ifdef RUN_FLASH
  wire cache_read_req_en;
  //Cache Ready Output
  reg  cache_ready_en;

  assign rdata_cache = dataout_int;
  assign cache_read_req_en = valid_cache & (~|wstrb_cache);
  assign address_int = cache_read_req_en ? {{(DATA_W-`FLASH_CACHE_ADDR_W){1'b0}},address_cache} : FL_ADDRESS;
  assign avalid_int = cache_read_req_en ? valid_cache : FL_VALIDFLG;

  assign ready_cache = cache_ready_en ? readyflash_int : 1'b0;
  always @(posedge clk_i, posedge arst_i) begin
    if (arst_i) cache_ready_en <= 1'b0;
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
  assign avalid_int  = FL_VALIDFLG;
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
      .validflag(avalid_int),
      .commtype(FL_COMMANDTP[2:0]),
      .spimode(FL_COMMANDTP[31:30]),
      .dtr_en(FL_COMMANDTP[20]),
      .fourbyteaddr_on(FL_COMMANDTP[21]),
      .tready(readyflash_int),

      .clk(clk_i),
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
