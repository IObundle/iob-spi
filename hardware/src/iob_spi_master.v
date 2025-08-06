`timescale 1ns / 1ps

`include "iob_spi_master_conf.vh"
`include "iob_spi_master_csrs_conf.vh"

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

   `include "iob_spi_master_wires.vs"

   // configuration control and status register file.
   `include "iob_spi_master_subblocks.vs"

   assign rst_int       = arst_i | fl_reset_wr;

   assign fl_ready_rd   = readyflash_int;

   //Cache interface connection
   assign fl_dataout_rd = dataout_int;

`ifdef RUN_FLASH
   wire cache_read_req_en;
   //Cache Ready Output
   reg  cache_ready_en;


   // Unused ports:
   //cache_wdata_i,
   assign cache_rvalid_o = 1'b1;

   assign cache_rdata_o = dataout_int;
   assign cache_read_req_en = cache_valid_i & (~|cache_wstrb_i);
   assign address_int = cache_read_req_en ? {{(DATA_W-`FLASH_CACHE_ADDR_W){1'b0}},cache_addr_i} : fl_address_wr;
   assign valid_int = cache_read_req_en ? cache_valid_i : fl_validflg_wr;

   assign cache_ready_o = cache_ready_en ? readyflash_int : 1'b0;
   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) cache_ready_en <= 1'b0;
      else begin
         case (cache_ready_en)
            1'b0: begin
               if (cache_valid_i) cache_ready_en <= 1'b1;
            end
            1'b1: begin
               if (readyflash_int) cache_ready_en <= 1'b0;
            end
            default: cache_ready_en <= 1'b0;
         endcase
      end
   end
`else
   assign address_int = fl_address_wr;
   assign valid_int   = fl_validflg_wr;
`endif

   //
   // Tristate buffers
   //
   wire dq0_tri_in;
   wire dq0_tri_en;
   wire dq0_tri_out;
   iob_iobuf #(
      .FPGA_TOOL(FPGA_TOOL)
   ) dq0_buf (
      .i_i  (dq0_tri_in),
      .t_i  (dq0_tri_en),
      .n_i  (1'b0),
      .o_o  (dq0_tri_out),
      .io_io(mosi_io)
   );
   wire dq1_tri_in;
   wire dq1_tri_en;
   wire dq1_tri_out;
   iob_iobuf #(
      .FPGA_TOOL(FPGA_TOOL)
   ) dq1_buf (
      .i_i  (dq1_tri_in),
      .t_i  (dq1_tri_en),
      .n_i  (1'b0),
      .o_o  (dq1_tri_out),
      .io_io(miso_io)
   );
   wire dq2_tri_in;
   wire dq2_tri_en;
   wire dq2_tri_out;
   iob_iobuf #(
      .FPGA_TOOL(FPGA_TOOL)
   ) dq2_buf (
      .i_i  (dq2_tri_in),
      .t_i  (dq2_tri_en),
      .n_i  (1'b0),
      .o_o  (dq2_tri_out),
      .io_io(wp_n_io)
   );
   wire dq3_tri_in;
   wire dq3_tri_en;
   wire dq3_tri_out;
   iob_iobuf #(
      .FPGA_TOOL(FPGA_TOOL)
   ) dq3_buf (
      .i_i  (dq3_tri_in),
      .t_i  (dq3_tri_en),
      .n_i  (1'b0),
      .o_o  (dq3_tri_out),
      .io_io(hold_n_io)
   );

   //Instantiate core
   spi_master_fl #(
      .CLKS_PER_HALF_SCLK(2)
   ) fl_spi0 (
      .clk_i(clk_i),
      .rst_i(rst_int),

      .data_in_i        (fl_datain_wr),
      .data_out_o       (dataout_int),
      .address_i        (address_int),
      .command_i        (fl_command_wr[7:0]),
      .ndata_bits_i     (fl_command_wr[14:8]),
      .dummy_cycles_i   (fl_command_wr[19:16]),
      .frame_struct_i   (fl_command_wr[29:20]),
      .xipbit_en_i      (fl_command_wr[31:30]),
      .commtype_i       (fl_commandtp_wr[2:0]),
      .dtr_en_i         (fl_commandtp_wr[20]),
      .fourbyteaddr_on_i(fl_commandtp_wr[21]),
      .spimode_i        (fl_commandtp_wr[31:30]),
      .validflag_i      (valid_int),
      .tready_o         (readyflash_int),

      //Flash Memory interface
      .sclk_o(sclk_o),
      .ss_o  (ss_o),

      .mosi_dq0_i  (dq0_tri_out),
      .miso_dq1_i  (dq1_tri_out),
      .wp_n_dq2_i  (dq2_tri_out),
      .hold_n_dq3_i(dq3_tri_out),

      .mosi_dq0_t_o  (dq0_tri_en),
      .miso_dq1_t_o  (dq1_tri_en),
      .wp_n_dq2_t_o  (dq2_tri_en),
      .hold_n_dq3_t_o(dq3_tri_en),

      .mosi_dq0_o  (dq0_tri_in),
      .miso_dq1_o  (dq1_tri_in),
      .wp_n_dq2_o  (dq2_tri_in),
      .hold_n_dq3_o(dq3_tri_in)

   );


endmodule
