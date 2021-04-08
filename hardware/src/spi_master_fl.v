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
    wire    xipbit_phase;
	
	reg [8:0]	r_sclk_edges_counter;

	wire	tranfers_done;
	wire	sclk_leade;
	wire	sclk_traile;
	reg     r_sclk_out_en;
	wire	sclk_int;

	reg [8:0]	r_sclk_edges;
	reg		r_transfer_start;
	
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
	
    wire [3:0] data_tx;
    wire [3:0] data_rx;
    assign data_tx = (recoverseq) ? dqvalues:
                        (dualtx_en) ? {{hold_n_int, wp_n_int},w_mosi[1:0]}:
                            (quadtx_en) ? w_mosi[3:0]:
                                {hold_n_int, wp_n_int, w_mosi[1],w_mosi[0]};
    //assign data_tx = (dualcommd || dualaddr || dualdatatx || dualalt) ? {{hold_n_int, wp_n_int},w_mosi[1:0]}:
    //                    (quadcommd || quadaddr || quaddatatx || quadalt) ? w_mosi[3:0]:
    //                        {hold_n_int, wp_n_int, w_mosi[1],w_mosi[0]};
    

    //Configure inout tristate i/o
    reg [3:0] oe = 4'b1111;
    //assign {hold_n_dq3, wp_n_dq2, miso_dq1, mosi_dq0} = oe? data_tx:4'hz;
    //assign {hold_n_dq3, wp_n_dq2, miso_dq1, mosi_dq0} = oe ? data_tx:
    //                                (quadcommd || quadaddr || quaddatatx || quadalt)? 4'hz:{2'b11, 2'hz};
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
		end else begin
			if (r_validedge) begin
				r_datain <= data_in;
				r_address <= address;
				r_command <= command;
				r_commandtype <= commtype;
				r_nmisobits <= ndata_bits;
				r_ndatatxbits <= ndata_bits;
				r_dummy_cycles <= dummy_cycles;
                r_frame_struct <= frame_struct;
                r_xipbit_en <= xipbit_en;
				r_inputread <= 1'b1;
			end
			else if (~validflag) begin
				r_inputread <= 1'b0;
			end//TODO reset r_nmisobits for idle states (default)
			else if (r_transfer_start) begin
				r_nmisobits <= 0;
				//r_dummy_cycles <= 0;
			end
		end
	end

	// Register inputs
	always @(posedge rst, posedge clk) begin
		if (rst) begin
			r_validedge <= 1'b0;
		end
		else begin
			if (validflag && (~r_inputread) && (~r_validedge)) begin
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

    assign dualcommd = (r_frame_struct[9:8] == 2'b01) ? 1'b1:1'b0;
    assign quadcommd = (r_frame_struct[9:8] == 2'b10) ? 1'b1:1'b0;
    assign dualaddr = (r_frame_struct[7:6] == 2'b01) ? 1'b1:1'b0;
    assign quadaddr = (r_frame_struct[7:6] == 2'b10) ? 1'b1:1'b0;
    assign dualdatatx = (r_frame_struct[5:4] == 2'b01) ? 1'b1:1'b0;
    assign quaddatatx = (r_frame_struct[5:4] == 2'b10) ? 1'b1:1'b0;
    assign dualrx = (r_frame_struct[3:2] == 2'b01) ? 1'b1:1'b0;
    assign quadrx = (r_frame_struct[3:2] == 2'b10) ? 1'b1:1'b0;
    assign dualalt = (r_frame_struct[1:0] == 2'b01) ? 1'b1:1'b0;
    assign quadalt = (r_frame_struct[1:0] == 2'b10) ? 1'b1:1'b0;

    //Build r_str2sendbuild
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
                            r_str2sendbuild <= {r_command, data_in, {32{1'b0}}};
                            end
                    3'b110: begin
                            r_str2sendbuild <= (r_4byteaddr_on) ? {r_address, {40{1'b0}}}: {r_address[23:0], {48{1'b0}}};            
                            end
                    default: begin
                            r_str2sendbuild <= (r_4byteaddr_on) ? {r_command, r_address, r_datain}:{r_command, r_address[23:0], r_datain, {8{1'b0}}};
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
    wire command_en, address_en;
    wire alt_en, datatx_en;
    assign command_en = (r_frame_struct[9:8] != 2'b11);
    assign address_en = (r_frame_struct[7:6] != 2'b11);
    assign datatx_en = (r_frame_struct[5:4] != 2'b11);
    assign alt_en = (r_frame_struct[1:0] != 2'b11);

    wire dualtx_en;
    wire quadtx_en;
    assign dualtx_en = (dualcommd && (curr_delayed==`COMM_PHASE) ) || 
                        (dualaddr && (curr_delayed==`ADDR_PHASE) )|| 
                        (dualdatatx && (curr_delayed==`DATATX_PHASE)) || 
                        (dualalt && (curr_delayed==`ALT_PHASE));
    assign quadtx_en = (quadcommd && (curr_delayed==`COMM_PHASE) ) || 
                        (quadaddr && (curr_delayed==`ADDR_PHASE) )|| 
                        (quaddatatx && (curr_delayed==`DATATX_PHASE)) || 
                        (quadalt && (curr_delayed==`ALT_PHASE));

    // Frame transmission phase

    reg [2:0] curr;
    reg [2:0] curr_delayed;
    
    always @(posedge clk, posedge rst) begin//Adding delay, or later on latchout
        if (rst) curr_delayed <= 0;
        else curr_delayed <= curr;
    end

    always @(posedge clk, posedge rst) begin
        if (rst) curr <= 0;
        else begin
            if (w_sending_done ) begin
                if (`LATCHIN_EDGE) curr <= `IDLE_PHASE;
                else curr <= curr;

            end else begin
                case (curr)
                    `IDLE_PHASE://not transfering
                    begin
                        if (r_transfer_start) begin
                            if (command_en) curr <= `COMM_PHASE;
                            else if ((!command_en) && address_en) curr <= `ADDR_PHASE;//(!)
                        end
                    end
                    `COMM_PHASE://command phase
                    begin
                        if (command_done && address_en) curr <= `ADDR_PHASE;
                        if (command_done && !address_en && datatx_en) curr <= `DATATX_PHASE;
                    end
                    `ADDR_PHASE://address phase
                    begin
                       if (address_done && datatx_en) curr <= `DATATX_PHASE;
                       else if (address_done && !datatx_en && alt_en) curr <= `ALT_PHASE;
                    end
                    `DATATX_PHASE://datatx phase
                    begin
                       if (datatx_done) curr <= `IDLE_PHASE; 
                    end
                    `ALT_PHASE://alt phase
                    begin
                        if (alt_done) curr <= `IDLE_PHASE;
                    end
                    /*3'b101://dummy TODO
                    begin
                        if (w_sending_done) curr <= 0;
                    end*/
                    default:;
                endcase
            end
        end
    end
    
    /*
    *   Phase done signals
        * */
    reg [5:0] r_command_size = 6'd8;
    reg [5:0] r_address_size = 6'd24;

    reg command_done;
    reg address_done;
    reg datatx_done;
    reg alt_done;

    wire [5:0] comm_addr_sum;
    wire [6:0] comm_addr_data_sum;
    assign comm_addr_sum = r_command_size + r_address_size;
    assign comm_addr_data_sum = r_command_size + r_address_size + r_ndatatxbits;
    always @* begin
        command_done = 1'b0;
        address_done = 1'b0;
        datatx_done = 1'b0;
        alt_done = 1'b0;
        case ({command_en, address_en, datatx_en, alt_done})
            4'b1000:
                if ((mosicounter >= r_command_size))
                    command_done = 1;
            4'b0100:
                if ((mosicounter >= r_address_size))
                    address_done = 1;
            4'b1100:   
            begin
                if ((mosicounter >= r_command_size))
                    command_done = 1;
                if (mosicounter >= (comm_addr_sum)) begin
                    command_done = 1;
                    address_done = 1;
                end
            end
            4'b1110:
            begin
                if ((mosicounter >= r_command_size))
                    command_done = 1;
                if (mosicounter >= (comm_addr_sum)) begin
                    command_done = 1;
                    address_done = 1;
                end
                if (mosicounter >= (comm_addr_data_sum)) begin
                    command_done = 1;
                    address_done = 1;
                    datatx_done = 1;
                end
            end
            4'b1111:
            begin
                if ((mosicounter >= r_command_size))
                    command_done = 1;
                if (mosicounter >= (comm_addr_sum)) begin
                    command_done = 1;
                    address_done = 1;
                end
                if (mosicounter >= (comm_addr_data_sum)) begin//alt
                    command_done = 1;
                    address_done = 1;
                    datatx_done = 1;
                    alt_done = 1;//for now, doesn't affect
                end
            end
            default:;
                //alt 
                //dummy
        endcase
    end

    wire [3:0] w_mosi;
    wire w_sending_done;
    wire w_mosifinish;
    wire [7:0] mosicounter;
    wire [31:0] w_misodata;

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
        .xipbit_en(xipbit_en),
        .xipbit_phase(xipbit_phase),
        .sending_done(w_sending_done),
        .mosifinish(w_mosifinish),
        .mosicounter(mosicounter),
        .read_data(w_misodata)
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
    assign w_addrcycles = dualaddr ? (r_4byteaddr_on? 7'd16: 7'd12):
                            quadaddr ? (r_4byteaddr_on? 7'd8: 7'd6):
                                (r_4byteaddr_on? 7'd32: 7'd24);
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
		end else begin
			r_counters_done <= 1'b0;
			if (r_setup_start) begin
					r_counters_done <= 1'b1;
					case(r_commandtype)
						3'b000:	begin//Only command
								r_counterstop <= 8'd8;//Parameterize with regs
								r_sclk_edges <= {w_commdcycles, 1'b0};
							end
						3'b001: begin//command + answer
								r_counterstop <= 8'd8;//Parameterize
								r_misoctrstop <= w_misocycles - 1'b1;
								r_sclk_edges <= {w_commdcycles + w_misocycles, 1'b0};
							end
						3'b010: begin//command + address + (+ dummy cycles +) + answer 
								r_counterstop <= 8'd8 + (r_4byteaddr_on? 8'd32:8'd24);
								r_misoctrstop <= w_misocycles - 1'b1;
								r_sclk_edges <= {w_commdcycles + w_addrcycles + r_dummy_cycles + w_misocycles, 1'b0};
							end
						3'b011:	begin//command + data_in
								r_counterstop <= 8'd8 + r_ndatatxbits;
								r_sclk_edges <= {w_commdcycles + w_datatxcycles,1'b0};
							end
						3'b100: begin//command + address + (+ dummy cycles +) + data_in 
								r_counterstop <= 8'd8 + (r_4byteaddr_on? 8'd32:8'd24) + r_ndatatxbits;
								r_sclk_edges <= {w_commdcycles + w_addrcycles + r_dummy_cycles + w_datatxcycles,1'b0};
							end
						3'b101: begin//command+address
								r_counterstop <= 8'd8 + (r_4byteaddr_on? 8'd32:8'd24);
								r_sclk_edges <= {w_commdcycles + w_addrcycles,1'b0};
							end
                        3'b110: begin//XIP mode, address + answer
                                r_counterstop <= (r_4byteaddr_on? 8'd32:8'd24);
								r_misoctrstop <= w_misocycles - 1'b1;
								r_sclk_edges <= {w_addrcycles + r_dummy_cycles + w_misocycles, 1'b0};
                            end
                        3'b111: begin//reset sequences
								r_counterstop <= r_ndatatxbits;
								r_sclk_edges <= {w_datatxcycles,1'b0};                       
                            end
					default:	begin
								r_counterstop <= 8'd8;
								//TODO other control signals default
								r_sclk_edges <= {w_commdcycles, 1'b0};
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
						data_out <= w_misodata;
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
