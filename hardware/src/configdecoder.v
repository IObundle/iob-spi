`timescale 1ns / 1ps

`define SPI_COM_W 8
`define SPI_ADDR_W 32
`define SPI_DATA_W 32

module configdecoder (
    input clk,
    input rst,

    input [ `SPI_COM_W-1:0] command,
    input [            2:0] commandtype,
    input [`SPI_ADDR_W-1:0] address,
    input [`SPI_DATA_W-1:0] datain,
    input [            1:0] spimode,
    input [            6:0] nmisobits,
    input [            6:0] ndatatxbits,
    input [            9:0] frame_struct,
    input [            3:0] dummy_cycles,
    input                   dtr_en,
    input                   fourbyteaddr_on,
    input                   setup_start,

    output dualrx,
    output quadrx,
    output dualcommd,
    output quadcommd,
    output dualaddr,
    output quadaddr,
    output dualdatatx,
    output quaddatatx,
    output dualalt,
    output quadalt,

    output reg [71:0] r_str2sendbuild,
    output reg [29:0] txcntmarks,
    output reg        r_build_done,
    output reg        r_counters_done,
    output reg [ 8:0] r_sclk_edges,
    output reg [ 7:0] r_counterstop,
    output reg [ 6:0] r_misoctrstop
);

  //Frame structure decoding/controls
  wire [6:0] w_misocycles;
  wire [3:0] w_commdcycles;
  wire [6:0] w_addrcycles;
  wire [3:0] w_altcycles;
  wire [6:0] w_datatxcycles;

  assign w_misocycles = dualrx ? {{1'b0, nmisobits[6:1]} + (|nmisobits[0])}:
                            quadrx ? {{2'b00, nmisobits[6:2]} + (|nmisobits[1:0])}:
                                nmisobits;
  assign w_commdcycles = dualcommd ? 4'd4 : quadcommd ? {4'd2} : 4'd8;
  assign w_addrcycles = dualaddr ? (fourbyteaddr_on ? 7'd16: 7'd12):
                            quadaddr ? (fourbyteaddr_on ? 7'd8: 7'd6):
                                (fourbyteaddr_on ? 7'd32: 7'd24);
  assign w_altcycles = 4'd0;
  assign w_datatxcycles = dualdatatx ? {{1'b0, ndatatxbits[6:1]} + (|ndatatxbits[0])}:
                                quaddatatx ? {{2'b00, ndatatxbits[6:2]} + (|ndatatxbits[1:0])}:
                                    ndatatxbits;

  assign dualcommd = (spimode==2'b01) ? 1'b1 :
                            (spimode==2'b10) ? 1'b0 :
                                (frame_struct[9:8] == 2'b01) ? 1'b1:1'b0;
  assign quadcommd = (spimode==2'b10) ? 1'b1 :
                            (spimode==2'b01) ? 1'b0 :
                                (frame_struct[9:8] == 2'b10) ? 1'b1:1'b0;
  assign dualaddr = (spimode==2'b01) ? 1'b1 :
                            (spimode==2'b10) ? 1'b0 :
                                (frame_struct[7:6] == 2'b01) ? 1'b1:1'b0;
  assign quadaddr = (spimode==2'b10) ? 1'b1 :
                            (spimode==2'b01) ? 1'b0 :
                                (frame_struct[7:6] == 2'b10) ? 1'b1:1'b0;
  assign dualdatatx = (spimode==2'b01) ? 1'b1 :
                            (spimode==2'b10) ? 1'b0 :
                                (frame_struct[5:4] == 2'b01) ? 1'b1:1'b0;
  assign quaddatatx = (spimode==2'b10) ? 1'b1 :
                            (spimode==2'b01) ? 1'b0 :
                                (frame_struct[5:4] == 2'b10) ? 1'b1:1'b0;
  assign dualrx = (spimode==2'b01) ? 1'b1 :
                            (spimode==2'b10) ? 1'b0 :
                                (frame_struct[3:2] == 2'b01) ? 1'b1:1'b0;
  assign quadrx = (spimode==2'b10) ? 1'b1 :
                            (spimode==2'b01) ? 1'b0 :
                                (frame_struct[3:2] == 2'b10) ? 1'b1:1'b0;
  assign dualalt = (spimode==2'b01) ? 1'b1 :
                            (spimode==2'b10) ? 1'b0 :
                                (frame_struct[1:0] == 2'b01) ? 1'b1:1'b0;
  assign quadalt = (spimode==2'b10) ? 1'b1 :
                            (spimode==2'b01) ? 1'b0 :
                                (frame_struct[1:0] == 2'b10) ? 1'b1:1'b0;

  //Build r_str2sendbuild
  wire [`SPI_DATA_W-1:0] w_revertedbytes;
  assign w_revertedbytes = {datain[7:0], datain[15:8], datain[23:16], datain[31:24]};  //not general
  always @(posedge rst, posedge clk) begin
    if (rst) begin
      r_str2sendbuild <= 72'h0;
      r_build_done <= 1'b0;
    end else begin
      r_build_done <= 1'b0;
      if (setup_start) begin
        r_build_done <= 1'b1;
        case (commandtype)
          3'b011: begin
            r_str2sendbuild <= {command, w_revertedbytes, {32{1'b0}}};
          end
          3'b110: begin
            r_str2sendbuild <= (fourbyteaddr_on) ? {address, {40{1'b0}}}: {address[23:0], {48{1'b0}}};
          end
          default: begin
            r_str2sendbuild <= (fourbyteaddr_on) ? {command, address, w_revertedbytes}:{command, address[23:0], w_revertedbytes, {8{1'b0}}};
          end
        endcase
      end
    end
  end

  always @(posedge rst, posedge clk) begin
    if (rst) begin
      r_counterstop <= 8'd0;
      r_misoctrstop <= 7'd8;
      r_sclk_edges <= 0;
      r_counters_done <= 1'b0;
      txcntmarks <= 0;
    end else begin
      r_counters_done <= 1'b0;
      if (setup_start) begin
        r_counters_done <= 1'b1;
        case (commandtype)
          3'b000: begin
            //Only command
            r_counterstop <= 8'd8;
            r_sclk_edges <= {w_commdcycles, 1'b0};
            txcntmarks[9:0] <= {frame_struct[9:8], 8'd8};  //command_size
            txcntmarks[19:10] <= 0;
            txcntmarks[29:20] <= 0;
          end
          3'b001: begin
            //command + answer
            r_counterstop <= 8'd8;
            r_misoctrstop <= nmisobits;
            r_sclk_edges <= {w_commdcycles + w_misocycles, 1'b0};
            txcntmarks[9:0] <= {frame_struct[9:8], 8'd8};  //command_size
            txcntmarks[19:10] <= 0;
            txcntmarks[29:20] <= 0;
          end
          3'b010: begin
            //command + address + (+ dummy cycles +) + answer
            r_counterstop <= 8'd8 + (fourbyteaddr_on ? 8'd32 : 8'd24);
            r_misoctrstop <= nmisobits;
            r_sclk_edges <= {w_commdcycles + (dtr_en ?  {1'b0,w_addrcycles[6:1]} : w_addrcycles) + dummy_cycles + (dtr_en ?  {1'b0,w_misocycles[6:1]} : w_misocycles), 1'b0} + (dtr_en ? 1'b1 : 0);
            txcntmarks[9:0] <= {frame_struct[9:8], 8'd8};  //command_size
            txcntmarks[19:10] <= {
              frame_struct[7:6], 8'd8 + (fourbyteaddr_on ? (8'd32) : (8'd24))
            };  //command_size + address_size
            txcntmarks[29:20] <= 0;
          end
          3'b011: begin  //command + data_in
            r_counterstop <= 8'd8 + ndatatxbits;
            r_sclk_edges <= {w_commdcycles + w_datatxcycles, 1'b0};
            txcntmarks[9:0] <= {frame_struct[9:8], 8'd8};  //command_size
            txcntmarks[19:10] <= {frame_struct[5:4], 8'd8 + ndatatxbits};  //command + data_in
            txcntmarks[29:20] <= 0;
          end
          3'b100: begin
            //command + address + data_in
            r_counterstop <= 8'd8 + (fourbyteaddr_on ? 8'd32 : 8'd24) + ndatatxbits;
            r_sclk_edges <= {w_commdcycles + w_addrcycles + w_datatxcycles, 1'b0};
            txcntmarks[9:0] <= {frame_struct[9:8], 8'd8};
            txcntmarks[19:10] <= {
              frame_struct[7:6], 8'd8 + (fourbyteaddr_on ? 8'd32 : 8'd24)
            };  //command + data_in
            txcntmarks[29:20] <= {
              frame_struct[5:4], 8'd8 + (fourbyteaddr_on ? 8'd32 : 8'd24) + ndatatxbits
            };  //command + data_in
          end
          3'b101: begin  //command+address
            r_counterstop <= 8'd8 + (fourbyteaddr_on ? 8'd32 : 8'd24);
            r_sclk_edges <= {w_commdcycles + w_addrcycles, 1'b0};
            txcntmarks[9:0] <= {frame_struct[9:8], 8'd8};
            txcntmarks[19:10] <= {
              frame_struct[7:6], (fourbyteaddr_on ? 8'd32 : 8'd24)
            };  //command + address
            txcntmarks[29:20] <= 0;
          end
          3'b110: begin  //XIP mode, address + answer
            r_counterstop <= (fourbyteaddr_on ? 8'd32 : 8'd24);
            r_misoctrstop <= nmisobits;
            r_sclk_edges <= {w_addrcycles + dummy_cycles + w_misocycles, 1'b0};
            txcntmarks[9:0] <= {frame_struct[7:6], (fourbyteaddr_on ? 8'd32 : 8'd24)};
            txcntmarks[19:10] <= 0;
            txcntmarks[29:20] <= 0;
          end
          3'b111: begin  //reset sequences
            r_counterstop <= ndatatxbits;
            r_sclk_edges <= {w_datatxcycles, 1'b0};
            txcntmarks[9:0] <= 0;
            txcntmarks[19:10] <= 0;
            txcntmarks[29:20] <= 0;
          end
          default: begin
            r_counterstop <= 8'd8;
            r_sclk_edges <= {w_commdcycles, 1'b0};
            txcntmarks[9:0] <= 0;
            txcntmarks[19:10] <= 0;
            txcntmarks[29:20] <= 0;
          end
        endcase
      end
    end
  end

endmodule
