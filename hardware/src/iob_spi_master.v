`timescale 1ns / 1ps

`include "iob_spi_master_conf.vh"
`include "iob_spi_master_swreg_def.vh"

`ifdef FLASH_ADDR_W
`define FLASH_CACHE_ADDR_W `FLASH_ADDR_W
`else
`define FLASH_CACHE_ADDR_W 24
`endif

module iob_spi_master #(
    `include "iob_spi_master_params.vs"
) (
    `include "iob_spi_master_io.vs"
);

  wire              valid_int;
  wire [    32-1:0] address_int;
  wire [DATA_W-1:0] dataout_int;
  //Ready signal from flash controller
  wire              readyflash_int;
  //Hard or Soft Reset
  reg               rst_int;

  //Software Accessible Registers
  `include "iob_spi_master_swreg_inst.vs"

  assign rst_int = arst_i | FL_RESET_wr;

  assign FL_READY_rd = readyflash_int;

  //Cache interface connection
  assign FL_DATAOUT_rd = dataout_int;

`ifdef RUN_FLASH
  wire cache_read_req_en;
  //Cache Ready Output
  reg  cache_ready_en;

  assign rdata_cache = dataout_int;
  assign cache_read_req_en = valid_cache & (~|wstrb_cache);
  assign address_int = cache_read_req_en ? {{(DATA_W-`FLASH_CACHE_ADDR_W){1'b0}},address_cache} : FL_ADDRESS_wr;
  assign valid_int = cache_read_req_en ? valid_cache : FL_VALIDFLG_wr;

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
  assign address_int = FL_ADDRESS_wr;
  assign valid_int  = FL_VALIDFLG_wr;
`endif

  //
  // Tristate buffers
  //
  wire dq0_tri_in;
  wire dq0_tri_en;
  wire dq0_tri_out;
  iob_iobuf dq0_buf (
      .i_i(dq0_tri_in),
      .t_i(dq0_tri_en),
      .n_i(1'b0),
      .o_o(dq0_tri_out),
      .io(MOSI)
  );
  wire dq1_tri_in;
  wire dq1_tri_en;
  wire dq1_tri_out;
  iob_iobuf dq1_buf (
      .i_i(dq1_tri_in),
      .t_i(dq1_tri_en),
      .n_i(1'b0),
      .o_o(dq1_tri_out),
      .io(MISO)
  );
  wire dq2_tri_in;
  wire dq2_tri_en;
  wire dq2_tri_out;
  iob_iobuf dq2_buf (
      .i_i(dq2_tri_in),
      .t_i(dq2_tri_en),
      .n_i(1'b0),
      .o_o(dq2_tri_out),
      .io(WP_N)
  );
  wire dq3_tri_in;
  wire dq3_tri_en;
  wire dq3_tri_out;
  iob_iobuf dq3_buf (
      .i_i(dq3_tri_in),
      .t_i(dq3_tri_en),
      .n_i(1'b0),
      .o_o(dq3_tri_out),
      .io(HOLD_N)
  );

  //Instantiate core
  spi_master_fl #(
      .CLKS_PER_HALF_SCLK(2)
  ) fl_spi0 (
      .clk_i(clk_i),
      .rst_i(rst_int),

      .data_in_i(FL_DATAIN_wr),
      .data_out_o(dataout_int),
      .address_i(address_int),
      .command_i(FL_COMMAND_wr[7:0]),
      .ndata_bits_i(FL_COMMAND_wr[14:8]),
      .dummy_cycles_i(FL_COMMAND_wr[19:16]),
      .frame_struct_i(FL_COMMAND_wr[29:20]),
      .xipbit_en_i(FL_COMMAND_wr[31:30]),
      .commtype_i(FL_COMMANDTP_wr[2:0]),
      .dtr_en_i(FL_COMMANDTP_wr[20]),
      .fourbyteaddr_on_i(FL_COMMANDTP_wr[21]),
      .spimode_i(FL_COMMANDTP_wr[31:30]),
      .validflag_i(valid_int),
      .tready_o(readyflash_int),

      //Flash Memory interface
      .sclk_o(SCLK),
      .ss_o(SS),

      .mosi_dq0_i(dq0_tri_out),
      .miso_dq1_i(dq1_tri_out),
      .wp_n_dq2_i(dq2_tri_out),
      .hold_n_dq3_i(dq3_tri_out),

      .mosi_dq0_t_o(dq0_tri_en),
      .miso_dq1_t_o(dq1_tri_en),
      .wp_n_dq2_t_o(dq2_tri_en),
      .hold_n_dq3_t_o(dq3_tri_en),

      .mosi_dq0_o(dq0_tri_in),
      .miso_dq1_o(dq1_tri_in),
      .wp_n_dq2_o(dq2_tri_in),
      .hold_n_dq3_o(dq3_tri_in)

  );


endmodule
