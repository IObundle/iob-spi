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
    input clk,
    input rst,

    //CONTROLLER FROM CPU
    input      [`SPI_DATA_W-1:0] data_in,
    output reg [`SPI_DATA_W-1:0] data_out,
    input      [`SPI_ADDR_W-1:0] address,
    input      [ `SPI_COM_W-1:0] command,
    input                        validflag,
    input      [`SPI_CTYP_W-1:0] commtype,
    input                        dtr_en,
    input      [            6:0] ndata_bits,
    input      [            3:0] dummy_cycles,
    input      [            9:0] frame_struct,
    input      [            1:0] xipbit_en,
    input      [            1:0] spimode,
    input                        fourbyteaddr_on,
    output reg                   tready,

    //SPI INTERFACE
    output reg sclk,
    output     ss,
    inout      mosi_dq0,
    inout      miso_dq1,
    inout      wp_n_dq2,
    inout      hold_n_dq3
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

  assign w_CPOL = (CPOL == 1);
  assign w_CPHA = (CPHA == 1);

  //sclk generator instance
  sclk_gen #(
      .CLKS_PER_HALF_SCLK(CLKS_PER_HALF_SCLK),
      .CPOL(CPOL),
      .CPHA(CPHA)
  ) sclk_gen0 (
      .clk(clk),
      .rst(rst),
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

  // Assign output
  always @(posedge rst, posedge clk) begin
    if (rst) sclk <= w_CPOL;  //default
    else sclk <= sclk_int;
  end

  //Drive wp_n and hold_n
  always @(posedge rst, posedge clk) begin
    if (rst) begin
      wp_n_int   <= 1'b1;
      hold_n_int <= 1'b1;
    end else begin
      wp_n_int   <= 1'b1;
      hold_n_int <= 1'b1;
    end
  end

  //Sizes reg
  reg [5:0] r_address_size;
  always @(posedge clk, posedge rst) begin
    if (rst) begin
      r_address_size <= 6'd24;
    end else begin
      r_address_size <= 6'd24;
      if (r_4byteaddr_on) r_address_size <= 6'd32;
    end
  end

  wire [3:0] data_tx;
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


  wire dualtx_en;
  wire quadtx_en;
  always @(posedge clk, posedge rst) begin
    if (rst) begin
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
  reg [3:0] oe = 4'b1111;
  wire quadcommd;
  wire quadaddr;
  wire quaddatatx;
  wire quadalt;
  wire quadrx;
  assign hold_n_dq3 = oe[3] ? data_tx[3] :(quadcommd || quadaddr || quaddatatx || quadalt || quadrx)? 1'hz:1'b1;
  assign wp_n_dq2 = oe[2] ? data_tx[2] :(quadcommd || quadaddr || quaddatatx || quadalt || quadrx)? 1'hz:1'b1;
  assign miso_dq1 = oe[1] ? data_tx[1] : 1'hz;
  assign mosi_dq0 = oe[0] ? data_tx[0] : 1'hz;

  assign data_rx = {hold_n_dq3, wp_n_dq2, miso_dq1, mosi_dq0};

  //Drive oe
  wire oe_latchout;
  wire w_mosifinish;
  assign oe_latchout = r_dtr_en ? `LATCHOUT_EDGE_DTR : `LATCHOUT_EDGE;
  always @(posedge clk, posedge rst) begin
    if (rst) oe <= 4'b1111;
    else begin
      oe <= 4'b1111;
      if (w_mosifinish) begin
        if (r_xipbit_en[1] && xipbit_phase) oe <= 4'b0001;
        else if (oe_latchout) oe <= 4'b0000;
        else oe <= oe;
      end
    end
  end

  // Register inputs on (validflag && tready)
  always @(posedge clk, posedge rst) begin
    if (rst) begin
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
      if (validflag && tready) begin
        r_datain <= data_in;
        r_address <= address;
        r_command <= command;
        r_commandtype <= commtype;
        r_nmisobits <= ndata_bits;
        r_ndatatxbits <= ndata_bits;
        r_dummy_cycles <= dummy_cycles;
        r_frame_struct <= frame_struct;
        r_xipbit_en <= xipbit_en;
        r_spimode <= spimode;
        r_4byteaddr_on <= fourbyteaddr_on;
        r_dtr_en <= dtr_en;
      end
    end
  end

  // Register inputs
  wire w_validedge;
  assign w_validedge = validflag && tready;
  always @(posedge rst, posedge clk) begin
    if (rst) begin
      r_validedge <= 1'b0;
    end else begin
      if (validflag && tready) begin
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
      .clk(clk),
      .rst(rst),

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
      .clk(clk),
      .rst(rst),

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
      .xipbit_en(xipbit_en),
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
  assign ss = r_ss_n;

  //Master State Machine
  reg [2:0] r_currstate;
  localparam IDLE = 3'h0;
  localparam SETUP = 3'h1;
  localparam TRANSFER = 3'h2;
  always @(posedge rst, posedge clk) begin
    if (rst) begin
      r_currstate <= IDLE;
      r_sclk_out_en <= 1'b0;
      r_ss_n <= 1'b1;
      r_transfer_start <= 1'b0;
      r_setup_start <= 1'b0;
      r_setup_rst <= 1'b0;
      tready <= 1'b1;
      data_out <= 0;
    end else begin
      case (r_currstate)
        IDLE: begin
          //default
          tready <= 1'b1;
          r_sclk_out_en <= 1'b0;
          r_ss_n <= 1'b1;
          r_transfer_start <= 1'b0;
          if (w_validedge) tready <= 1'b0;
          if (r_validedge) begin
            r_setup_rst <= 1'b1;
            r_setup_start <= 1'b1;
            data_out <= 0;
            tready <= 1'b0;
            r_currstate <= SETUP;
          end
        end

        SETUP: begin
          r_setup_rst <= 1'b0;
          r_transfer_start <= 1'b0;
          r_setup_start <= 1'b0;
          tready <= 1'b0;
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
          tready <= 1'b0;
          if (transfers_done) begin
            r_ss_n <= 1'b1;
            r_sclk_out_en <= 1'b0;
            data_out <= (r_endianness) ? w_misodata : w_misodatarev;
            tready <= 1'b1;
            r_currstate <= IDLE;
          end
        end

        default: begin
          r_sclk_out_en <= 1'b0;
          r_ss_n <= 1'b1;
          tready <= 1'b1;
          data_out <= 0;
          r_currstate <= IDLE;
        end
      endcase
    end
  end
endmodule
