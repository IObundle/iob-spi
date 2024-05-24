`timescale 1ns / 1ps

`define SPI_DATA_W 32
`define SPI_COM_W 8
`define SPI_CTYP_W 3
`define SPI_ADDR_W 32
`define SPI_DATA_MINW 8

`define LATCHIN_EDGE (sclk_leade & ~w_CPHA | sclk_traile & w_CPHA)
`define LATCHOUT_EDGE (sclk_leade & w_CPHA | sclk_traile & ~w_CPHA)
`define LATCHOUT_EDGE_DTR (dtr_edge0 | dtr_edge1)
`define IDLE_PHASE 3'b000
`define COMM_PHASE 3'b001
`define ADDR_PHASE 3'b010
`define DATATX_PHASE 3'b011
`define ALT_PHASE 3'b100


module spi_master_fl #(
    parameter CLKS_PER_HALF_SCLK = 2,
    parameter CPOL = 1,
    parameter CPHA = 1
) (

    //CONTROLLER INTERFACE
    input clk_i,
    input rst_i,

    //CONTROLLER FROM CPU
    input      [`SPI_DATA_W-1:0] data_in_i,
    output reg [`SPI_DATA_W-1:0] data_out_o,
    input      [`SPI_ADDR_W-1:0] address_i,
    input      [ `SPI_COM_W-1:0] command_i,
    input      [            6:0] ndata_bits_i,
    input      [            3:0] dummy_cycles_i,
    input      [            9:0] frame_struct_i,
    input      [            1:0] xipbit_en_i,
    input      [`SPI_CTYP_W-1:0] commtype_i,
    input                        dtr_en_i,
    input                        fourbyteaddr_on_i,
    input      [            1:0] spimode_i,
    input                        validflag_i,
    output reg                   tready_o,

    //SPI INTERFACE
    output reg sclk_o,
    output     ss_o,

    input      mosi_dq0_i,
    input      miso_dq1_i,
    input      wp_n_dq2_i,
    input      hold_n_dq3_i,

    output     mosi_dq0_t_o,
    output     miso_dq1_t_o,
    output     wp_n_dq2_t_o,
    output     hold_n_dq3_t_o,

    output     mosi_dq0_o,
    output     miso_dq1_o,
    output     wp_n_dq2_o,
    output     hold_n_dq3_o
);

  //
  // INPUT LATCH REGS
  //

  //Register TX data, address, command
  reg  [`SPI_DATA_W-1:0] r_datain;
  reg  [`SPI_ADDR_W-1:0] r_address;
  reg  [ `SPI_COM_W-1:0] r_command;
  reg  [            2:0] r_commandtype;
  reg                    r_4byteaddr_on = 1'b0;
  reg  [            6:0] r_ndatatxbits;
  reg  [            9:0] r_frame_struct = 0;
  reg  [            6:0] r_nmisobits;
  reg  [            3:0] r_dummy_cycles;
  reg  [            1:0] r_xipbit_en;
  reg                    r_validedge = 1'b0;
  reg  [            1:0] r_spimode;
  reg                    r_dtr_en;

  reg                    tready_int;

  //
  // BEHAVIOUR REGS
  //

  //MOSI controller signals
  reg                    r_transfer_start;
  reg                    r_setup_start;
  reg                    r_setup_rst;
  reg                    r_sclk_out_en;
  reg                    wp_n_int;
  reg                    hold_n_int;
  reg                    r_endianness = 1'b0;  // 0 for little-endian, on data read from flash

  wire [           71:0] w_str2sendbuild;
  wire [            7:0] w_counterstop;
  wire [            6:0] w_misoctrstop;
  wire [            8:0] w_sclk_edges;
  wire [           29:0] txcntmarks;
  wire                   w_counters_done;
  wire                   w_build_done;
  wire                   xipbit_phase;
  wire                   transfers_done;
  wire                   sclk_leade;
  wire                   sclk_traile;
  wire                   sclk_int;
  wire                   dtr_edge0;
  wire                   dtr_edge1;

  wire                   w_CPOL;
  wire                   w_CPHA;

  // STATUS MACHINE
  reg [2:0] r_currstate;
  localparam IDLE = 3'h0;
  localparam SETUP = 3'h1;
  localparam TRANSFER = 3'h2;

  wire w_validedge;

  always @(posedge clk_i, posedge rst_i) begin
      if (rst_i) begin
          tready_o <= 1'b1;
      end else if ((r_currstate == IDLE) && (w_validedge || r_validedge)) begin
          tready_o <= 1'b0;
      end else begin 
          tready_o <= tready_int;
      end
  end
  assign w_CPOL = (CPOL == 1);
  assign w_CPHA = (CPHA == 1);

  //sclk_o generator instance
  sclk_gen #(
      .CLKS_PER_HALF_SCLK(CLKS_PER_HALF_SCLK),
      .CPOL(CPOL),
      .CPHA(CPHA)
  ) sclk_gen0 (
      .clk(clk_i),
      .rst(rst_i),
      .sclk_edges(w_sclk_edges),
      .sclk_en(r_sclk_out_en),
      .op_start(r_transfer_start),
      .op_done(transfers_done),
      .dtr_edge0(dtr_edge0),
      .dtr_edge1(dtr_edge1),
      .sclk_leadedge(sclk_leade),
      .sclk_trailedge(sclk_traile),
      .sclk_int(sclk_int)
  );

  reg sclk_int_r;

  // delay sclk_int_r by one clock cycle to match dq_out_r and ss_o
  always @(posedge clk_i, posedge rst_i) begin
      if (rst_i) begin
          sclk_int_r <= w_CPOL;
      end else begin
          sclk_int_r <= sclk_int;
      end
  end

  // Assign output
  always @(posedge rst_i, posedge clk_i) begin
    if (rst_i) sclk_o <= w_CPOL;  //default
    else sclk_o <= sclk_int_r;
  end

  //Drive wp_n and hold_n
  always @(posedge rst_i, posedge clk_i) begin
    if (rst_i) begin
      wp_n_int   <= 1'b1;
      hold_n_int <= 1'b1;
    end else begin
      wp_n_int   <= 1'b1;
      hold_n_int <= 1'b1;
    end
  end

  //Sizes reg
  reg [5:0] r_address_size;
  always @(posedge clk_i, posedge rst_i) begin
    if (rst_i) begin
      r_address_size <= 6'd24;
    end else begin
      r_address_size <= 6'd24;
      if (r_4byteaddr_on) r_address_size <= 6'd32;
    end
  end

  reg [3:0] oe;
  wire [3:0] data_tx;
  reg [3:0] dq_out_r;
  wire dq2_out;
  wire dq3_out;
  wire [3:0] data_rx;
  reg dualtx_state;
  reg quadtx_state;
  wire [3:0] w_mosi;
  reg recoverseq;
  reg [3:0] dqvalues;
  assign data_tx = (recoverseq) ? dqvalues:
                        (dualtx_state) ? {{hold_n_int, wp_n_int},w_mosi[1:0]}:
                            (quadtx_state) ? w_mosi[3:0]:
                                {hold_n_int, wp_n_int, w_mosi[1] ,w_mosi[0]};

  assign dq2_out = oe[2] ? data_tx[2] : 1'b1;
  assign dq3_out = oe[3] ? data_tx[3] : 1'b1;
  always @(posedge clk_i, posedge rst_i) begin
      if (rst_i) begin
          dq_out_r <= 4'd0;
      end else begin
          dq_out_r <= {dq3_out, dq2_out, data_tx[1:0]};
      end
  end

  wire dualtx_en;
  wire quadtx_en;
  always @(posedge clk_i, posedge rst_i) begin
    if (rst_i) begin
      dualtx_state <= 1'b0;
      quadtx_state <= 1'b0;
    end else begin
      if (`LATCHOUT_EDGE) begin
        dualtx_state <= dualtx_en;
        quadtx_state <= quadtx_en;
      end
    end
  end

  //Configure inout tristate i/o
  wire quadcommd;
  wire quadaddr;
  wire quaddatatx;
  wire quadalt;
  wire quadrx;


  reg [3:0] dq_tri_r;
  wire dq2_tri;
  wire dq3_tri;

  assign dq2_tri = ~oe[2] & (quadcommd || quadaddr || quaddatatx || quadalt || quadrx);
  assign dq3_tri = ~oe[3] & (quadcommd || quadaddr || quaddatatx || quadalt || quadrx);

  always @(posedge clk_i, posedge rst_i) begin
      if (rst_i) begin
          dq_tri_r <= 4'd0;
      end else begin
          dq_tri_r <= {dq3_tri, dq2_tri, ~oe[1], ~oe[0]};
      end
  end

  // Tristate control: 0: IO = core output, 1: core input = IO
  assign mosi_dq0_t_o   = dq_tri_r[0];
  assign miso_dq1_t_o   = dq_tri_r[1];
  assign wp_n_dq2_t_o   = dq_tri_r[2];
  assign hold_n_dq3_t_o = dq_tri_r[3];

  assign mosi_dq0_o   = dq_out_r[0];
  assign miso_dq1_o   = dq_out_r[1];
  assign wp_n_dq2_o   = dq_out_r[2];
  assign hold_n_dq3_o = dq_out_r[3];

  assign data_rx = {hold_n_dq3_i, wp_n_dq2_i, miso_dq1_i, mosi_dq0_i};

  //Drive oe
  wire oe_latchout;
  wire w_mosifinish;
  assign oe_latchout = r_dtr_en ? `LATCHOUT_EDGE_DTR : `LATCHOUT_EDGE;
  always @(posedge clk_i, posedge rst_i) begin
    if (rst_i) oe <= 4'b1111;
    else begin
      oe <= 4'b1111;
      if (w_mosifinish) begin
        if (r_xipbit_en[1] && xipbit_phase) oe <= 4'b0001;
        else if (oe_latchout) oe <= 4'b0000;
        else oe <= oe;
      end
    end
  end

  // Register inputs on (validflag_i && tready_int)
  always @(posedge clk_i, posedge rst_i) begin
    if (rst_i) begin
      r_datain <= `SPI_DATA_W'b0;
      r_address <= `SPI_ADDR_W'b0;
      r_command <= `SPI_COM_W'b0;
      r_commandtype <= `SPI_CTYP_W'b111;
      r_nmisobits <= 7'd32;
      r_ndatatxbits <= 7'd32;
      r_dummy_cycles <= 4'd0;
      r_frame_struct <= 10'h0;
      r_xipbit_en <= 2'b00;
      r_spimode <= 2'b00;
      r_4byteaddr_on <= 1'b0;
      r_dtr_en <= 1'b0;
    end else begin
      if (validflag_i && tready_int) begin
        r_datain <= data_in_i;
        r_address <= address_i;
        r_command <= command_i;
        r_commandtype <= commtype_i;
        r_nmisobits <= ndata_bits_i;
        r_ndatatxbits <= ndata_bits_i;
        r_dummy_cycles <= dummy_cycles_i;
        r_frame_struct <= frame_struct_i;
        r_xipbit_en <= xipbit_en_i;
        r_spimode <= spimode_i;
        r_4byteaddr_on <= fourbyteaddr_on_i;
        r_dtr_en <= dtr_en_i;
      end
    end
  end

  // Register inputs
  assign w_validedge = validflag_i && tready_int;
  always @(posedge rst_i, posedge clk_i) begin
    if (rst_i) begin
      r_validedge <= 1'b0;
    end else begin
      if (validflag_i && tready_int) begin
        r_validedge <= 1'b1;
      end else begin
        r_validedge <= 1'b0;
      end
    end
  end

  wire dualrx;
  wire dualcommd;
  wire dualaddr;
  wire dualdatatx;
  wire dualalt;

  configdecoder configdecoder0 (
      .clk(clk_i),
      .rst(rst_i),

      .command(r_command),
      .commandtype(r_commandtype),
      .address(r_address),
      .datain(r_datain),
      .spimode(r_spimode),
      .nmisobits(r_nmisobits),
      .ndatatxbits(r_ndatatxbits),
      .frame_struct(r_frame_struct),
      .dummy_cycles(r_dummy_cycles),
      .dtr_en(r_dtr_en),
      .fourbyteaddr_on(r_4byteaddr_on),
      .setup_start(r_setup_start),

      .dualrx(dualrx),
      .quadrx(quadrx),
      .dualcommd(dualcommd),
      .quadcommd(quadcommd),
      .dualaddr(dualaddr),
      .quadaddr(quadaddr),
      .dualdatatx(dualdatatx),
      .quaddatatx(quaddatatx),
      .dualalt(dualalt),
      .quadalt(quadalt),

      .r_str2sendbuild(w_str2sendbuild),
      .txcntmarks(txcntmarks),
      .r_build_done(w_build_done),
      .r_counters_done(w_counters_done),
      .r_sclk_edges(w_sclk_edges),
      .r_counterstop(w_counterstop),
      .r_misoctrstop(w_misoctrstop)
  );



  wire w_sending_done;
  wire [7:0] mosicounter;
  wire [31:0] w_misodata;
  wire [31:0] w_misodatarev;

  //Instantiate module to tx and rx data
  latchspi latchspi0 (
      .clk(clk_i),
      .rst(rst_i),

      .data_tx(w_mosi),
      .data_rx(data_rx),
      .sclk_en(r_sclk_out_en),
      .latchin_en(`LATCHIN_EDGE),
      .latchout_en(`LATCHOUT_EDGE),
      .latchout_dtr_en(`LATCHOUT_EDGE_DTR),
      .dtr_en(r_dtr_en),
      .setup_rst(r_setup_rst),
      .loadtxdata_en(w_counters_done && w_build_done),
      .mosistop_cnt(w_counterstop),
      .txstr(w_str2sendbuild),
      .dualtx_en(dualtx_en),
      .quadtx_en(quadtx_en),
      .dualrx(dualrx),
      .quadrx(quadrx),
      .dummy_cycles(r_dummy_cycles),
      .misostop_cnt(w_misoctrstop),
      .numrxbits(r_nmisobits),
      .xipbit_en(xipbit_en_i),
      .xipbit_phase(xipbit_phase),
      .sending_done(w_sending_done),
      .mosifinish(w_mosifinish),
      .mosicounter(mosicounter),
      .txcntmarks(txcntmarks),
      .spimode(r_spimode),
      .read_data(w_misodata),
      .read_datarev(w_misodatarev)
  );

  //Detect recover sequence
  always @* begin
    dqvalues   = 4'h0;
    recoverseq = 1'b0;
    if (r_commandtype == 3'b111) begin
      dqvalues[0] = (r_frame_struct[1:0]==2'b00 || r_frame_struct[1:0]==2'b01) ? r_frame_struct[0]: 1'bz;
      dqvalues[1] = (r_frame_struct[3:2]==2'b00 || r_frame_struct[3:2]==2'b01) ? r_frame_struct[2]: 1'bz;
      dqvalues[2] = (r_frame_struct[5:4]==2'b00 || r_frame_struct[5:4]==2'b01) ? r_frame_struct[4]: 1'bz;
      dqvalues[3] = (r_frame_struct[7:6]==2'b00 || r_frame_struct[7:6]==2'b01) ? r_frame_struct[6]: 1'bz;
      recoverseq = 1'b1;
    end
  end


  //Assert ss
  reg r_ss_n;
  reg r_ss_n_r;
  assign ss_o = r_ss_n_r;

  // delay ss_n by one clock cycle to match dq_out_r
  always @(posedge clk_i, posedge rst_i) begin
      if (rst_i) begin
          r_ss_n_r <= 1'd1;
      end else begin
          r_ss_n_r <= r_ss_n;
      end
  end

  //Master State Machine
  always @(posedge rst_i, posedge clk_i) begin
    if (rst_i) begin
      r_currstate <= IDLE;
      r_sclk_out_en <= 1'b0;
      r_ss_n <= 1'b1;
      r_transfer_start <= 1'b0;
      r_setup_start <= 1'b0;
      r_setup_rst <= 1'b0;
      tready_int <= 1'b1;
      data_out_o <= 0;
    end else begin
      case (r_currstate)
        IDLE: begin
          //default
          tready_int <= 1'b1;
          r_sclk_out_en <= 1'b0;
          r_ss_n <= 1'b1;
          r_transfer_start <= 1'b0;
          if (w_validedge) tready_int <= 1'b0;
          if (r_validedge) begin
            r_setup_rst <= 1'b1;
            r_setup_start <= 1'b1;
            data_out_o <= 0;
            tready_int <= 1'b0;
            r_currstate <= SETUP;
          end
        end

        SETUP: begin
          r_setup_rst <= 1'b0;
          r_transfer_start <= 1'b0;
          r_setup_start <= 1'b0;
          tready_int <= 1'b0;
          if (w_build_done && w_counters_done) begin
            r_transfer_start <= 1'b1;
            r_ss_n <= 1'b0;
            //r_sclk_out_en <= 1'b1;
            r_currstate <= TRANSFER;
          end
        end

        TRANSFER: begin
          r_ss_n <= 1'b0;
          r_sclk_out_en <= 1'b1;
          tready_int <= 1'b0;
          if (transfers_done) begin
            r_ss_n <= 1'b1;
            r_sclk_out_en <= 1'b0;
            data_out_o <= (r_endianness) ? w_misodata : w_misodatarev;
            tready_int <= 1'b1;
            r_currstate <= IDLE;
          end
        end

        default: begin
          r_sclk_out_en <= 1'b0;
          r_ss_n <= 1'b1;
          tready_int <= 1'b1;
          data_out_o <= 0;
          r_currstate <= IDLE;
        end
      endcase
    end
  end
endmodule
