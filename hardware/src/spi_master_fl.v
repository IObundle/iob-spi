`timescale 1ns / 1ps
`include "iob_lib.vh"
`define SPI_DATA_W 32 
`define SPI_COM_W 8
`define SPI_CTYP_W 3
`define SPI_ADDR_W 32
`define SPI_DATA_MINW 8

`define LATCHIN_EDGE (sclk_leade & ~w_CPHA | sclk_traile & w_CPHA)
`define LATCHOUT_EDGE (sclk_leade & w_CPHA | sclk_traile & ~w_CPHA)
`define IDLE_PHASE 3'b000
`define COMM_PHASE 3'b001
`define ADDR_PHASE 3'b010
`define DATATX_PHASE 3'b011
`define ALT_PHASE 3'b100


module spi_master_fl
#(
	parameter	CLKS_PER_HALF_SCLK=2,
	parameter	CPOL = 1,
	parameter	CPHA = 1
	)
(
	
	//CONTROLLER INTERFACE
	input		clk,
	input 		rst,

	//CONTROLLER FROM CPU
	input [`SPI_DATA_W-1:0]			data_in,
	output reg [`SPI_DATA_W-1:0]		data_out,
	input [`SPI_ADDR_W-1:0]			address,
	input [`SPI_COM_W-1:0]			command,
	input 					validflag,
	input [`SPI_CTYP_W-1:0]		        commtype,
	input [6:0]				ndata_bits,	
	input [3:0]				dummy_cycles,
    input [9:0]             frame_struct,
    input [1:0]             xipbit_en,
    input                   manualframe_en,
    input [1:0]             spimode,
    input                   fourbyteaddr_on,
	output reg				validflag_out,
	output reg				tready,

	//SPI INTERFACE
	output reg		sclk,
	output		ss,
	inout	    mosi_dq0,
	inout		miso_dq1,
	inout		wp_n_dq2,
	inout		hold_n_dq3
);

	//Register TX data, address, command
	reg [`SPI_DATA_W-1:0]	r_datain;
	reg [`SPI_ADDR_W-1:0]	r_address;
	reg [`SPI_COM_W-1:0]	r_command;

	//Extra reg for mode controlling
	reg [2:0]	r_commandtype;
	reg		    r_4byteaddr_on = 1'b0;
	reg [7:0]	r_counterstop;
	reg [6:0]	r_misoctrstop;

	//MOSI controller signals
	reg [71:0]	r_str2sendbuild;//Parameterize with max
    reg [6:0]   r_ndatatxbits;

	//MISO controller signals
	reg [6:0]		r_misocounter;
	reg [6:0]		r_nmisobits;
	
	//Synchronization signals
	reg     r_inputread = 1'b0;

	reg         r_validedge = 1'b0;
	reg [1:0]   r_validoutHold = 2'b10;

    //Frame structure
    reg [9:0]   r_frame_struct = 0;

	//SCLK generation signals
	reg		r_setup_start;
	reg		r_counters_done;
	reg		r_build_done;
	reg		r_misofinish;
	reg		r_setup_rst;
	reg [3:0]	r_dummy_cycles;

	reg		wp_n_int;
	reg		hold_n_int;

    reg [1:0]   r_xipbit_en;    
    reg         r_manualframe_en; 
    reg [1:0]        r_spimode;
    reg [9:0] txcntmarks [2:0];

    wire    xipbit_phase;
	
	reg [8:0]	r_sclk_edges_counter;

	wire	tranfers_done;
	wire	sclk_leade;
	wire	sclk_traile;
	reg     r_sclk_out_en;
	wire	sclk_int;

	reg [8:0]	r_sclk_edges;
	reg		r_transfer_start;
    
    reg r_endianness = 1'b0;// 0 for little-endian, on data read from flash
	
	//assign sclk_halfperiod = {1'b0, sclk_period[5:1]};
	
	wire w_CPOL;
	wire w_CPHA;

	assign w_CPOL = (CPOL==1);
	assign w_CPHA = (CPHA==1);

    //sclk generator instance
    sclk_gen
    #(
        .CLKS_PER_HALF_SCLK(CLKS_PER_HALF_SCLK),
        .CPOL(CPOL),
        .CPHA(CPHA)
    )
    sclk_gen0
    (
        .clk(clk),
        .rst(rst),
        .sclk_edges(r_sclk_edges),
        .sclk_en(r_sclk_out_en),
        .op_start(r_transfer_start),
        .op_done(tranfers_done),
        .sclk_leadedge(sclk_leade),
        .sclk_trailedge(sclk_traile),
        .sclk_int(sclk_int)
    );

	// Assign output
	//assign sclk = sclk_int;
	always @(posedge rst, posedge clk) begin
		if (rst) sclk <= w_CPOL; //default
		else sclk <= sclk_int;
	end

	//Drive wp_n and hold_n
	always @(posedge rst, posedge clk) begin
		if (rst) begin
			wp_n_int <= 1'b1;
			hold_n_int <= 1'b1;
		end else begin
			wp_n_int <= 1'b1;
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
            if(r_4byteaddr_on)
                r_address_size <= 6'd32;
        end
    end

    wire [3:0] data_tx;
    wire [3:0] data_rx;
    reg dualtx_state;
    reg quadtx_state;
    assign data_tx = (recoverseq) ? dqvalues:
                        (dualtx_state) ? {{hold_n_int, wp_n_int},w_mosi[1:0]}:
                            (quadtx_state) ? w_mosi[3:0]:
                                {hold_n_int, wp_n_int, w_mosi[1] ,w_mosi[0]};//check w_mosi[1] later
    
    
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
    assign hold_n_dq3 = oe[3] ? data_tx[3] :(quadcommd || quadaddr || quaddatatx || quadalt || quadrx)? 1'hz:1'b1;
    assign wp_n_dq2 = oe[2] ? data_tx[2] :(quadcommd || quadaddr || quaddatatx || quadalt || quadrx)? 1'hz:1'b1;
    assign miso_dq1 = oe[1] ? data_tx[1] :1'hz;
    assign mosi_dq0 = oe[0] ? data_tx[0] :1'hz;

    assign data_rx = {hold_n_dq3, wp_n_dq2, miso_dq1, mosi_dq0};

    //Drive oe
    always @(posedge clk, posedge rst) begin
        if (rst) oe <= 4'b1111;
        else begin
            oe <= 4'b1111;
            //if (w_mosifinish) oe <= 1'b0;
            if (w_mosifinish) begin
                if (r_xipbit_en[1] && xipbit_phase) oe <= 4'b0001; 
                else if (`LATCHOUT_EDGE) oe <= 4'b0000;
                else oe <= oe;
            end
        end
    end

	//Receive data to transfer from upperlevel controller
	always @(posedge clk, posedge rst) begin
		if (rst) begin
			r_datain <= `SPI_DATA_W'b0;
			r_address <= `SPI_ADDR_W'b0;
			r_command <= `SPI_COM_W'b0;
			r_commandtype <= `SPI_CTYP_W'b111;
			r_inputread <= 1'b0;
			r_nmisobits <= 7'd32;
            r_ndatatxbits <= 7'd32;
			r_dummy_cycles <= 4'd0;
            r_frame_struct <= 10'h0;
            r_xipbit_en <= 2'b00;
            r_manualframe_en <= 1'b0;
            r_spimode <= 2'b00;
            r_4byteaddr_on <= 1'b0;
		end else begin
            //r_inputread <= 1'b0;
			//if (r_validedge) begin
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
                r_manualframe_en <= manualframe_en;
                r_spimode <= spimode;
                r_4byteaddr_on <= fourbyteaddr_on;
				//r_inputread <= 1'b1;
			end
			//else if (~validflag) begin
			//	r_inputread <= 1'b0;
			//end//TODO reset r_nmisobits for idle states (default)
			else if (r_transfer_start) begin
				r_nmisobits <= 0;
				//r_dummy_cycles <= 0;
			end
		end
	end

	// Register inputs
    wire w_validedge; 
    //assign w_validedge = validflag && (~r_inputread) && (~r_validedge);
    assign w_validedge = validflag && tready; 
	always @(posedge rst, posedge clk) begin
		if (rst) begin
			r_validedge <= 1'b0;
		end
		else begin
			//if (validflag && (~r_inputread) && (~r_validedge)) begin
			if (validflag && tready) begin
				r_validedge <= 1'b1;
			end else begin
				r_validedge <= 1'b0;
			end
		end
	end

    //Frame structure decoding TODO
    wire dualcommd, quadcommd;
    wire dualaddr, quadaddr;
    wire dualalt, quadalt;
    wire dualrx, quadrx;
    wire dualdatatx, quaddatatx;

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

    /**
    *   Mosi Frame Driving control
    *   From frame_struct
    *   Data transmit control fsm
        * **/
    //manual_frame_en
    //
    wire dualtx_en;
    wire quadtx_en;

    wire [3:0] w_mosi;
    wire w_sending_done;
    wire w_mosifinish;
    wire [7:0] mosicounter;
    wire [31:0] w_misodata;
    wire [31:0] w_misodatarev;

    //Instantiate module to tx and rx data
    latchspi latchspi0
    (
        .clk(clk),
        .rst(rst),
        
        .data_tx(w_mosi),
        .data_rx(data_rx),
        .sclk_en(r_sclk_out_en),
        .latchin_en(`LATCHIN_EDGE),
        .latchout_en(`LATCHOUT_EDGE),
        .setup_rst(r_setup_rst),
        .loadtxdata_en(r_counters_done && r_build_done),
        .mosistop_cnt(r_counterstop),
        .txstr(r_str2sendbuild),
        .dualtx_en(dualtx_en),
        .quadtx_en(quadtx_en),
        .dualrx(dualrx),
        .quadrx(quadrx),
        .dummy_cycles(r_dummy_cycles),
        .misostop_cnt(r_misoctrstop),
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
    reg [3:0] dqvalues;
    reg recoverseq;
    always @* begin
       dqvalues = 4'h0; 
       recoverseq = 1'b0;
       if (r_commandtype == 3'b111) begin
           dqvalues[0] = (r_frame_struct[1:0]==2'b00 || r_frame_struct[1:0]==2'b01) ? r_frame_struct[0]: 1'bz;
           dqvalues[1] = (r_frame_struct[3:2]==2'b00 || r_frame_struct[3:2]==2'b01) ? r_frame_struct[2]: 1'bz;
           dqvalues[2] = (r_frame_struct[5:4]==2'b00 || r_frame_struct[5:4]==2'b01) ? r_frame_struct[4]: 1'bz;
           dqvalues[3] = (r_frame_struct[7:6]==2'b00 || r_frame_struct[7:6]==2'b01) ? r_frame_struct[6]: 1'bz;
           recoverseq = 1'b1;
       end
    end

	//MUX
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
								r_sclk_edges <= {w_commdcycles + w_addrcycles + r_dummy_cycles + w_misocycles, 1'b0};
                                txcntmarks[0] <= {r_frame_struct[9:8], 8'd8}; //command_size
                                txcntmarks[1] <= {r_frame_struct[7:6], 8'd8 + (r_4byteaddr_on ? 8'd32:8'd24)}; //command_size + address_size
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
	
	//Assert ss
	assign ss = r_ss_n;
	
	//Master State Machine
	reg [2:0]		r_currstate;
	localparam IDLE = 3'h0;
	localparam SETUP = 3'h1;
	localparam TRANSFER = 3'h2;
	reg	r_ss_n;
	always @(posedge rst, posedge clk) begin
		if (rst) begin
			r_currstate <= IDLE;
			r_sclk_out_en <= 1'b0;
			r_ss_n <= 1'b1;
			r_transfer_start <= 1'b0;
			r_setup_start <= 1'b0;
			r_setup_rst <= 1'b0;
			tready <= 1'b1;
            validflag_out <= 1'b1;
			data_out <= 0;
		end else begin
			validflag_out <= 1'b1;//No use for now
			case(r_currstate)
				IDLE:
				begin
					//default
					tready <= 1'b1;
					r_sclk_out_en <= 1'b0;
					r_ss_n <= 1'b1;
					r_transfer_start <= 1'b0;
					if(w_validedge) tready <= 1'b0;
					if(r_validedge) begin
						r_setup_rst <= 1'b1;
						r_setup_start <= 1'b1;
						data_out <= 0;
						tready <= 1'b0;
						r_currstate <= SETUP;
					end
				end

				SETUP:
				begin
					r_setup_rst <= 1'b0;
					r_transfer_start <= 1'b0;
					r_setup_start <= 1'b0;
					tready <= 1'b0;
					if(r_build_done && r_counters_done) begin
						r_transfer_start <= 1'b1;
						r_ss_n <= 1'b0;
						//r_sclk_out_en <= 1'b1;
						r_currstate <= TRANSFER;
					end
				end

				TRANSFER:
				begin
					r_ss_n <= 1'b0;
					r_sclk_out_en <= 1'b1;
					tready <= 1'b0;
					if(tranfers_done) begin
						r_ss_n <= 1'b1;
						r_sclk_out_en <= 1'b0;
						data_out <= (r_endianness) ? w_misodata : w_misodatarev;
                        tready <= 1'b1;
						r_currstate <= IDLE;
					end
				end

				default:
				begin
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
