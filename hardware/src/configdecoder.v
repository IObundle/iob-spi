`timescale 1ns / 1ps


module configdecoder
(
    input clk,
    input rst,

    input [`SPI_COM_W-1:0]	r_command,
    input [`SPI_ADDR_W-1:0]	r_address,
    input [`SPI_DATA_W-1:0]	r_datain,
    input [1:0]     r_spimode,
    input [6:0]		r_nmisobits,
    input [9:0]     r_frame_struct,
    input           r_dtr_en,
    input		    r_4byteaddr_on,

    output  dualcommd,
    output  quadcommd,
    output  dualaddr,
    output  quadaddr,
    output  dualdatatx,
    output  quaddatatx,
    output  dualrx,
    output  quadrx,
    output  dualalt,
    output  quadalt,

	output reg [71:0]	r_str2sendbuild,//Parameterize with max
    output reg [9:0] txcntmarks [2:0],
	output reg		r_build_done,
	output reg		r_counters_done,
	output reg [8:0]	r_sclk_edges,
	output reg [7:0]	r_counterstop,
	output reg [6:0]	r_misoctrstop
);

	//Frame structure decoding/controls
    wire [6:0] w_misocycles;
    wire [3:0] w_commdcycles;
    wire [6:0] w_addrcycles;
    wire [3:0] w_altcycles;//TODO
    wire [6:0] w_datatxcycles;

    assign w_misocycles = dualrx ? {{1'b0, r_nmisobits[6:1]} + (|r_nmisobits[0])}: 
                            quadrx ? {{2'b00, r_nmisobits[6:2]} + (|r_nmisobits[1:0])}: 
                                r_nmisobits;
    assign w_commdcycles = dualcommd ? 4'd4: //Parameterize with reg later, param, now fixed at max 8bits
                            quadcommd ? {4'd2}:
                                4'd8;
    assign w_addrcycles = dualaddr ? (r_4byteaddr_on ? 7'd16: 7'd12):
                            quadaddr ? (r_4byteaddr_on ? 7'd8: 7'd6):
                                (r_4byteaddr_on ? 7'd32: 7'd24);
    assign w_altcycles = 4'd0;
    assign w_datatxcycles = dualdatatx ? {{1'b0, r_ndatatxbits[6:1]} + (|r_ndatatxbits[0])}:
                                quaddatatx ? {{2'b00, r_ndatatxbits[6:2]} + (|r_ndatatxbits[1:0])}:
                                    r_ndatatxbits;

    assign dualcommd = (r_spimode==2'b01) ? 1'b1 :
                            (r_spimode==2'b10) ? 1'b0 : 
                                (r_frame_struct[9:8] == 2'b01) ? 1'b1:1'b0;
    assign quadcommd = (r_spimode==2'b10) ? 1'b1 :
                            (r_spimode==2'b01) ? 1'b0 :
                                (r_frame_struct[9:8] == 2'b10) ? 1'b1:1'b0;
    assign dualaddr = (r_spimode==2'b01) ? 1'b1 :
                            (r_spimode==2'b10) ? 1'b0 :
                                (r_frame_struct[7:6] == 2'b01) ? 1'b1:1'b0;
    assign quadaddr = (r_spimode==2'b10) ? 1'b1 :
                            (r_spimode==2'b01) ? 1'b0 :
                                (r_frame_struct[7:6] == 2'b10) ? 1'b1:1'b0;
    assign dualdatatx = (r_spimode==2'b01) ? 1'b1 :
                            (r_spimode==2'b10) ? 1'b0 :
                                (r_frame_struct[5:4] == 2'b01) ? 1'b1:1'b0;
    assign quaddatatx = (r_spimode==2'b10) ? 1'b1 :
                            (r_spimode==2'b01) ? 1'b0 :
                                (r_frame_struct[5:4] == 2'b10) ? 1'b1:1'b0;
    assign dualrx = (r_spimode==2'b01) ? 1'b1 :
                            (r_spimode==2'b10) ? 1'b0 :
                                (r_frame_struct[3:2] == 2'b01) ? 1'b1:1'b0;
    assign quadrx = (r_spimode==2'b10) ? 1'b1 :
                            (r_spimode==2'b01) ? 1'b0 :
                                (r_frame_struct[3:2] == 2'b10) ? 1'b1:1'b0;
    assign dualalt = (r_spimode==2'b01) ? 1'b1 :
                            (r_spimode==2'b10) ? 1'b0 :
                                (r_frame_struct[1:0] == 2'b01) ? 1'b1:1'b0;
    assign quadalt = (r_spimode==2'b10) ? 1'b1 :
                            (r_spimode==2'b01) ? 1'b0 :
                                (r_frame_struct[1:0] == 2'b10) ? 1'b1:1'b0;

    //Build r_str2sendbuild
    wire [`SPI_DATA_W-1:0] w_revertedbytes;
    assign w_revertedbytes = {r_datain[7:0], r_datain[15:8], r_datain[23:16], r_datain[31:24]};//not general
	always @(posedge rst, posedge clk) begin
		if (rst) begin
			r_str2sendbuild <= 72'h0;//not accounting for alt mode
			r_build_done <= 1'b0;
		end else begin
			r_build_done <= 1'b0;
			if (r_setup_start) begin
                r_build_done <= 1'b1;
                case(r_commandtype)
                    3'b011: begin
                            r_str2sendbuild <= {r_command, w_revertedbytes, {32{1'b0}}};
                            end
                    3'b110: begin
                            r_str2sendbuild <= (r_4byteaddr_on) ? {r_address, {40{1'b0}}}: {r_address[23:0], {48{1'b0}}};            
                            end
                    default: begin
                            r_str2sendbuild <= (r_4byteaddr_on) ? {r_command, r_address, w_revertedbytes}:{r_command, r_address[23:0], w_revertedbytes, {8{1'b0}}};
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
            txcntmarks[0] <= 0;
            txcntmarks[1] <= 0;
            txcntmarks[2] <= 0;
		end else begin
			r_counters_done <= 1'b0;
			if (r_setup_start) begin
					r_counters_done <= 1'b1;
					case(r_commandtype)
						3'b000:	begin//Only command
								r_counterstop <= 8'd8;//Parameterize with regs
								r_sclk_edges <= {w_commdcycles, 1'b0};
                                txcntmarks[0] <= {r_frame_struct[9:8], 8'd8}; //command_size
                                txcntmarks[1] <= 0; //command_size
                                txcntmarks[2] <= 0; //command_size
							end
						3'b001: begin//command + answer
								r_counterstop <= 8'd8;//Parameterize
								r_misoctrstop <= r_nmisobits;
								r_sclk_edges <= {w_commdcycles + w_misocycles, 1'b0};
                                txcntmarks[0] <= {r_frame_struct[9:8], 8'd8}; //command_size
                                txcntmarks[1] <= 0; 
                                txcntmarks[2] <= 0;
							end
						3'b010: begin//command + address + (+ dummy cycles +) + answer 
								r_counterstop <= 8'd8 + (r_4byteaddr_on ? 8'd32:8'd24);
								r_misoctrstop <= r_nmisobits;
								r_sclk_edges <= {w_commdcycles + (r_dtr_en ?  {1'b0,w_addrcycles[6:1]} : w_addrcycles) + r_dummy_cycles + (r_dtr_en ?  {1'b0,w_misocycles[6:1]} : w_misocycles), 1'b0} + (r_dtr_en ? 1'b1 : 0);
                                txcntmarks[0] <= {r_frame_struct[9:8], 8'd8}; //command_size
                                txcntmarks[1] <= {r_frame_struct[7:6], 8'd8 + (r_4byteaddr_on ? (r_dtr_en ? 8'd16 : 8'd32):(r_dtr_en ? 8'd12 : 8'd24))}; //command_size + address_size
                                txcntmarks[2] <= 0; 
							end
						3'b011:	begin//command + data_in
								r_counterstop <= 8'd8 + r_ndatatxbits;
								r_sclk_edges <= {w_commdcycles + w_datatxcycles,1'b0};
                                txcntmarks[0] <= {r_frame_struct[9:8], 8'd8}; //command_size
                                txcntmarks[1] <= {r_frame_struct[5:4], 8'd8 + r_ndatatxbits}; //command + data_in 
                                txcntmarks[2] <= 0;
							end
						3'b100: begin//command + address + data_in (+dummy cycles ?) 
								r_counterstop <= 8'd8 + (r_4byteaddr_on ? 8'd32:8'd24) + r_ndatatxbits;
								r_sclk_edges <= {w_commdcycles + w_addrcycles + w_datatxcycles,1'b0};//(+r_dummycycles)
                                txcntmarks[0] <= {r_frame_struct[9:8], 8'd8};
                                txcntmarks[1] <= {r_frame_struct[7:6], 8'd8 + (r_4byteaddr_on ? 8'd32:8'd24)}; //command + data_in 
                                txcntmarks[2] <= {r_frame_struct[5:4], 8'd8 + (r_4byteaddr_on ? 8'd32:8'd24) + r_ndatatxbits}; //command + data_in 
							end
						3'b101: begin//command+address
								r_counterstop <= 8'd8 + (r_4byteaddr_on ? 8'd32:8'd24);
								r_sclk_edges <= {w_commdcycles + w_addrcycles,1'b0};
                                txcntmarks[0] <= {r_frame_struct[9:8], 8'd8}; //command_size
                                txcntmarks[1] <= {r_frame_struct[7:6], (r_4byteaddr_on ? 8'd32:8'd24)}; //command + address 
                                txcntmarks[2] <= 0;
							end
                        3'b110: begin//XIP mode, address + answer
                                r_counterstop <= (r_4byteaddr_on ? 8'd32:8'd24);
								r_misoctrstop <= r_nmisobits;
								r_sclk_edges <= {w_addrcycles + r_dummy_cycles + w_misocycles, 1'b0};
                                txcntmarks[0] <= {r_frame_struct[7:6], (r_4byteaddr_on ? 8'd32:8'd24)};
                                txcntmarks[1] <= 0; 
                                txcntmarks[2] <= 0;
                            end
                        3'b111: begin//reset sequences
								r_counterstop <= r_ndatatxbits;
								r_sclk_edges <= {w_datatxcycles,1'b0};                       
                                txcntmarks[0] <= 0;
                                txcntmarks[1] <= 0;
                                txcntmarks[2] <= 0; 
                            end
					default:	begin
								r_counterstop <= 8'd8;
								//TODO other control signals default
								r_sclk_edges <= {w_commdcycles, 1'b0};
                                txcntmarks[0] <= 0;
                                txcntmarks[1] <= 0; 
                                txcntmarks[2] <= 0; 
							end
					endcase
			end
		end
	end

endmodule
