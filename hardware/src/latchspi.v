`timescale 1ns / 1ps

`define SINGLEMODE0 2'b00
`define SINGLEMODE1 2'b11
`define DUALMODE 2'b01
`define QUADMODE 2'b10
`define SINGLEMODEON (spimode==`SINGLEMODE0 || spimode==`SINGLEMODE1)
`define DUALMODEON (spimode==`DUALMODE)
`define QUADMODEON (spimode==`QUADMODE)

module latchspi (
    input clk,
    input rst,

    output [3:0] data_tx,
    input [3:0] data_rx,
    input sclk_en,
    input latchin_en,
    input latchout_en,
    input latchout_dtr_en,
    input dtr_en,
    input setup_rst,
    input loadtxdata_en,
    input [7:0] mosistop_cnt,
    input [71:0] txstr,
    output dualtx_en,
    output quadtx_en,
    input dualrx,
    input quadrx,
    input [3:0] dummy_cycles,
    input [6:0] misostop_cnt,
    input [1:0] xipbit_en,
    input [29:0] txcntmarks,
    input [1:0] spimode,
    input [6:0] numrxbits,
    output xipbit_phase,
    output sending_done,
    output mosifinish,
    output [7:0] mosicounter,
    output [31:0] read_data,
    output [31:0] read_datarev
);


  //Drive mosi
  reg [3:0] r_mosi;
  reg [7:0] r_txindexer;
  reg [7:0] r_mosicounter;
  reg r_mosifinish;
  reg r_sending_done;
  reg r_extradummy;

  reg [71:0] r_str2sendbuild;

  reg [31:0] r_misodata;
  reg [6:0] r_misocounter;

  //Load tx data into array
  always @(posedge clk, posedge rst) begin
    if (rst) r_str2sendbuild <= 0;
    else begin
      if (loadtxdata_en)  //pulse signal, 1 clk cycle
        r_str2sendbuild <= txstr;
    end
  end

  //enable dtr latchout
  reg  r_dtr_on;
  wire command_done;
  always @(posedge clk, posedge rst) begin
    if (rst) r_dtr_on <= 1'b0;
    else begin
      if (setup_rst) r_dtr_on <= 0;
      else if (command_done && latchout_en) r_dtr_on <= 1'b1;
    end
  end

  assign command_done = r_mosicounter >= 'd8;

  //assign to output
  assign data_tx = r_mosi;
  assign mosicounter = r_mosicounter;
  assign read_data = r_misodata;
  assign mosifinish = dtr_en ? r_sending_done : r_mosifinish;
  assign sending_done = r_sending_done;

  wire latchout_tx_en;
  assign latchout_tx_en = dtr_en ? (command_done ? (r_dtr_on ? latchout_dtr_en : 0) : latchout_en) : latchout_en;

  wire w_xipbit_phase;
  wire latchin_rx_en;
  always @(posedge clk, posedge rst) begin
    if (rst) begin
      r_mosi <= 4'h0;
      r_mosicounter <= 8'd0;
      r_mosifinish <= 1'b0;
      r_sending_done <= 1'b0;
      r_txindexer <= 8'd71;
      r_extradummy <= 1'b0;
    end else begin
      if (latchout_tx_en && sclk_en && (~r_mosifinish)) begin
        if (quadtx_en) begin
          r_mosi[3:0]   <= r_str2sendbuild[r_txindexer-:4];
          r_txindexer   <= r_txindexer - 3'h4;
          r_mosicounter <= r_mosicounter + 3'h4;
        end else if (dualtx_en) begin
          r_mosi[1:0]   <= r_str2sendbuild[r_txindexer-:2];
          r_txindexer   <= r_txindexer - 3'h2;
          r_mosicounter <= r_mosicounter + 3'h2;
        end else begin
          r_mosi[0] <= r_str2sendbuild[r_txindexer-:1];
          r_txindexer <= r_txindexer - 3'h1;
          r_mosicounter <= r_mosicounter + 3'h1;
        end
      end else if (xipbit_en[1] && w_xipbit_phase) begin  //Drive xip confirmation bit
        r_mosi[0] <= xipbit_en[0];
      end
      r_extradummy <= 1'b0;
      if (r_mosicounter == mosistop_cnt) begin
        r_mosicounter <= 8'd0;
        r_txindexer <= 8'd71;
        r_sending_done <= 1'b1;
        r_extradummy <= 1'b1;
      end
      if (r_sending_done && latchin_rx_en) begin
        r_mosifinish <= 1'b1;
      end
      if (setup_rst) begin
        r_mosifinish   <= 1'b0;
        r_sending_done <= 1'b0;
      end
    end
  end

  //Go through the dummy cycles
  reg  [3:0] r_dummy_counter;
  reg        r_dummy_done;
  reg        r_xipbit_phase;
  wire       dummy_count_en;
  assign dummy_count_en = (r_mosifinish && latchout_en || (dtr_en ? r_extradummy : 0)) && (~r_dummy_done);
  assign xipbit_phase = w_xipbit_phase;
  assign w_xipbit_phase = dummy_count_en & (r_dummy_counter == dummy_cycles);

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      r_dummy_counter <= 4'h0;
      r_dummy_done <= 1'b0;
      r_xipbit_phase <= 1'b0;
    end else begin
      if (setup_rst) begin
        r_dummy_counter <= dummy_cycles;
        r_dummy_done <= 1'b0;
        r_xipbit_phase <= 1'b0;
      end else if (dummy_count_en) begin
        r_dummy_counter <= r_dummy_counter - 1'b1;
        r_xipbit_phase  <= (r_dummy_counter == dummy_cycles);
      end else if (r_dummy_counter == 0 && latchin_en) begin
        r_dummy_done <= 1'b1;
      end
    end
  end

  reg opaque_cycle;
  reg dcnt;
  always @(posedge clk, posedge rst) begin
    if (rst) begin
      opaque_cycle <= 1'b0;
      dcnt <= 1'b0;
    end else begin
      opaque_cycle <= 1'b0;
      if (setup_rst) begin
        dcnt <= 1'b0;
      end else if (r_dummy_done && dcnt == 1'b0) begin
        opaque_cycle <= 1'b1;
        dcnt <= dcnt + 1'b1;
      end
    end
  end

  //Reverse endianness of misodata
  reg [31:0] w_misodatarev;
  assign read_datarev = w_misodatarev;
  //Assuming max 32 bits received 
  always @* begin
    w_misodatarev = 32'd0;
    case (numrxbits)
      7'd8: begin
        w_misodatarev = r_misodata;
      end
      7'd16: begin
        w_misodatarev = {{16{1'b0}}, r_misodata[7:0], r_misodata[15:8]};
      end
      7'd24: begin
        w_misodatarev = {{8{1'b0}}, r_misodata[7:0], r_misodata[15:8], r_misodata[23:16]};
      end
      7'd32: begin
        w_misodatarev = {r_misodata[7:0], r_misodata[15:8], r_misodata[23:16], r_misodata[31:24]};
      end
      default:
      w_misodatarev = {r_misodata[7:0], r_misodata[15:8], r_misodata[23:16], r_misodata[31:24]};
    endcase
  end

  //Drive miso
  assign latchin_rx_en = dtr_en ? ((latchin_en || latchout_en) && ~opaque_cycle) : (latchin_en);
  always @(posedge clk, posedge rst) begin
    if (rst) begin
      r_misodata <= 32'd0;
      r_misocounter <= 7'd0;
    end else begin
      if (latchin_rx_en && sclk_en && (r_mosifinish) && (r_dummy_done)) begin
        if (quadrx) begin
          r_misodata <= {r_misodata[27:0], {data_rx[3], data_rx[2], data_rx[1], data_rx[0]}};
          r_misocounter <= r_misocounter + 3'h4;
        end else if (dualrx) begin
          r_misodata <= {r_misodata[29:0], {data_rx[1], data_rx[0]}};
          r_misocounter <= r_misocounter + 3'h2;
        end else begin
          r_misodata <= {r_misodata[30:0], {data_rx[1]}};
          r_misocounter <= r_misocounter + 3'h1;
        end
      end
      if (setup_rst) begin
        r_misocounter <= 7'd0;
        r_misodata <= 0;
      end
    end
  end

  // Control lanes to use when on req
  reg [1:0] nextcnt;
  wire [9:0] txcntholder = (nextcnt=='h0) ? txcntmarks[9:0] : 
                                (nextcnt=='h1) ? txcntmarks[19:10] : 
                                    (nextcnt=='h2) ? txcntmarks[29:20] : 0;

  wire modeswitch_en = (`SINGLEMODEON && r_mosicounter == txcntholder[7:0] && r_mosicounter < mosistop_cnt);
  wire [1:0] mode = txcntholder[9:8];
  wire quad_en_test = (mode == 2'b10) ? 1'b1 : 1'b0;
  wire dual_en_test = (mode == 2'b01) ? 1'b1 : 1'b0;

  assign dualtx_en = (`DUALMODEON) ? 1'b1 : (`QUADMODEON) ? 1'b0 : dual_en_test;
  assign quadtx_en = (`QUADMODEON) ? 1'b1 : (`DUALMODEON) ? 1'b0 : quad_en_test;

  always @(posedge clk, posedge rst) begin
    if (rst) begin
      nextcnt <= 2'h0;
    end else begin
      if (setup_rst) nextcnt <= 0;
      else begin
        if (modeswitch_en) begin
          nextcnt <= nextcnt + 1'b1;
        end
      end
    end
  end


endmodule
