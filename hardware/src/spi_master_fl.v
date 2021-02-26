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
	reg		r_4byteaddr_on = 1'b0;
	reg [7:0]	r_counterstop;
	reg [6:0]	r_misoctrstop;

	//MOSI controller signals
	reg [7:0]	r_mosicounter;
	reg [71:0]	r_str2sendbuild;//Parameterize with max
    reg [6:0]   r_ndatatxbits;

	//MISO controller signals
	reg [6:0]		r_misocounter;
	reg [`SPI_DATA_W-1:0]	r_misodata;
	reg [6:0]		r_nmisobits;
	
	//Synchronization signals
	reg     r_expct_answer = 1'b0;	
	reg     r_inputread = 1'b0;

	reg         r_validedge = 1'b0;
	reg [1:0]   r_validoutHold = 2'b10;

    //Frame structure
    reg [9:0]   r_frame_struct = 0;

	//SCLK generation signals
	//reg [5:0] sclk_period = 6'd0;
	//wire [5:0] sclk_halfperiod;
	reg		r_setup_start;
	reg		r_counters_done;
	reg		r_build_done;
	reg		r_transfers_done;
	reg		r_mosifinish;
	reg		r_misofinish;
	reg		r_setup_rst;
	reg		r_sending_done; 
	reg [3:0]	r_dummy_cycles;

	reg		wp_n_int;
	reg		hold_n_int;
	
	reg [8:0]	r_sclk_edges_counter;

	reg 	sclk_leade;
	reg		sclk_traile;
	reg		r_sclk_out_en;
	reg		sclk_int;
	reg [$clog2(CLKS_PER_HALF_SCLK*2)-1:0]	clk_counter;

	reg [8:0]	r_sclk_edges;
	reg		r_transfer_start;
	
	//assign sclk_halfperiod = {1'b0, sclk_period[5:1]};
	
	wire w_CPOL;
	wire w_CPHA;

	assign w_CPOL = (CPOL==1);
	assign w_CPHA = (CPHA==1);

	always @(posedge clk, posedge rst) begin
		if (rst) begin
			sclk_leade <= 1'b0;
			sclk_traile <= 1'b0;
			sclk_int <= w_CPOL;
			clk_counter <= 0; 
			r_sclk_edges_counter <= 9'h0;
			r_transfers_done <= 1'b0;
		end else begin
			if (r_transfer_start) begin
					if(r_sclk_edges_counter > 0) begin
						if (clk_counter == CLKS_PER_HALF_SCLK-1) begin
							sclk_leade <= 1'b1;
							sclk_traile <= 1'b0;
							r_sclk_edges_counter <= r_sclk_edges_counter - 1'b1;
							if (r_sclk_out_en) sclk_int <= ~sclk_int;
							clk_counter <= clk_counter + 1'b1;
						end else if (clk_counter == CLKS_PER_HALF_SCLK*2-1) begin
							sclk_leade <= 1'b0;
							sclk_traile <= 1'b1;
							r_sclk_edges_counter <= r_sclk_edges_counter - 1'b1;
							if (r_sclk_out_en) sclk_int <= ~sclk_int;
							clk_counter <= clk_counter + 1'b1;
						end else begin
							sclk_leade <= 1'b0;
							sclk_traile <= 1'b0;
							clk_counter <= clk_counter + 1'b1;
						end
					end else begin
						r_transfers_done <= 1'b1;
						sclk_traile <= 1'b0;
						sclk_leade <= 1'b0;
					end
			end else begin
				sclk_int <= w_CPOL; //Initial sclk polarity
				sclk_leade <= 1'b0;
				sclk_traile <= 1'b0;
				clk_counter <= 0; 
				r_transfers_done <= 1'b0;
				r_sclk_edges_counter <= r_sclk_edges;
			end
		end
	end
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
	//assign wp_n = wp_n_int;
	//assign hold_n = hold_n_int;
    /*assign data_tx[0] = r_mosi; 
    assign data_tx[1] = 1'bz;
    assign data_tx[2] = wp_n_int;
	assign data_tx[3] = hold_n_int;*/
	
    wire [3:0] data_tx;
    wire [3:0] data_rx;
    assign data_tx = (dualtx_en) ? {{hold_n_int, wp_n_int},r_mosi[1:0]}:
                        (quadtx_en) ? r_mosi[3:0]:
                            {hold_n_int, wp_n_int, r_mosi[1],r_mosi[0]};
    //assign data_tx = (dualcommd || dualaddr || dualdatatx || dualalt) ? {{hold_n_int, wp_n_int},r_mosi[1:0]}:
    //                    (quadcommd || quadaddr || quaddatatx || quadalt) ? r_mosi[3:0]:
    //                        {hold_n_int, wp_n_int, r_mosi[1],r_mosi[0]};
    

    //Configure inout tristate i/o
    reg oe = 1'b1;
    assign {hold_n_dq3, wp_n_dq2, miso_dq1, mosi_dq0} = oe? data_tx:4'hz;
    assign data_rx = {hold_n_dq3, wp_n_dq2, miso_dq1, mosi_dq0};

    //Drive oe
    always @(posedge clk, posedge rst) begin
        if (rst) oe <= 1'b1;
        else begin
            oe <= 1'b1;
            if (r_mosifinish) oe <= 1'b0;
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
    wire dualcommd;
    wire quadcommd;
    wire dualaddr;
    wire quadaddr;
    wire dualalt;
    wire quadalt;
    wire quadrx;
    wire dualrx;
    wire dualdatatx;
    wire quaddatatx;

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
					if (~r_4byteaddr_on) begin//add alt support
						r_str2sendbuild <= (r_commandtype == 3'b011) ? {r_command, data_in, {32{1'b0}}}: {r_command, r_address[23:0], r_datain, {8{1'b0}}};
					end else begin
						r_str2sendbuild <= (r_commandtype == 3'b011) ? {r_command, data_in, {32{1'b0}}}: {r_command, r_address, r_datain};
					end
			end
		end
	end

		
    /**
    *   Mosi Frame Driving control
    *   From frame_struct
    *   Data transmit control fsm
        *
        * **/
    wire command_en;
    wire address_en;
    wire alt_en;
    wire datatx_en;
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

    /*
    *   Frame transmission phase
        * */

    reg [2:0] curr;
    reg [2:0] curr_delayed;
    
    always @(posedge clk, posedge rst) begin//Adding delay, or later on latchout
        if (rst) curr_delayed <= 0;
        else curr_delayed <= curr;
    end

    always @(posedge clk, posedge rst) begin
        if (rst) curr <= 0;
        else begin
            if (r_sending_done ) begin
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
                        if (r_sending_done) curr <= 0;
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
                if ((r_mosicounter >= r_command_size))
                    command_done = 1;
            4'b0100:
                if ((r_mosicounter >= r_address_size))
                    address_done = 1;
            4'b1100:   
            begin
                if ((r_mosicounter >= r_command_size))
                    command_done = 1;
                if (r_mosicounter >= (comm_addr_sum)) begin
                    command_done = 1;
                    address_done = 1;
                end
            end
            4'b1110:
            begin
                if ((r_mosicounter >= r_command_size))
                    command_done = 1;
                if (r_mosicounter >= (comm_addr_sum)) begin
                    command_done = 1;
                    address_done = 1;
                end
                if (r_mosicounter >= (comm_addr_data_sum)) begin
                    command_done = 1;
                    address_done = 1;
                    datatx_done = 1;
                end
            end
            4'b1111:
            begin
                if ((r_mosicounter >= r_command_size))
                    command_done = 1;
                if (r_mosicounter >= (comm_addr_sum)) begin
                    command_done = 1;
                    address_done = 1;
                end
                if (r_mosicounter >= (comm_addr_data_sum)) begin//alt
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
	//Drive mosi
    reg [3:0] r_mosi;
    reg [7:0] r_txindexer;
	always @(posedge clk, posedge rst) begin
		if (rst) begin
			//mosi <= 1'b0;
            r_mosi <= 1'b0;
			r_mosicounter <= 8'd0;
			r_mosifinish <= 1'b0;
			r_sending_done <= 1'b0;
            r_txindexer <= 8'd71;
		end else begin
			//if(r_transfer_start) begin end
			if (`LATCHOUT_EDGE && r_sclk_out_en && (~r_mosifinish)) begin
                if (quadtx_en) begin
                    r_mosi[3:0] <= r_str2sendbuild[r_txindexer -: 4];//Check index constants
                    r_txindexer <= r_txindexer - 3'h4;
                    r_mosicounter <= r_mosicounter + 3'h4;
                end else if(dualtx_en) begin
                    r_mosi[1:0] <= r_str2sendbuild[r_txindexer -: 2];
                    r_txindexer <= r_txindexer - 3'h2;
                    r_mosicounter <= r_mosicounter + 3'h2;
                end else begin
                    r_mosi[0] <= r_str2sendbuild[r_txindexer -: 1];
                    r_txindexer <= r_txindexer - 3'h1;
                    r_mosicounter <= r_mosicounter + 3'h1;
                end
			end
            if(r_mosicounter == r_counterstop) begin
                r_mosicounter <= 8'd0;
                r_txindexer <= 8'd71;
                r_sending_done <= 1'b1;
            end
			if (r_sending_done && `LATCHIN_EDGE) begin
				r_mosifinish <= 1'b1;
			end
			if (r_setup_rst) begin
				r_mosifinish <= 1'b0;
				r_sending_done <= 1'b0;
			end
		end
	end

	//Go through the dummy cycles
	reg [3:0]		r_dummy_counter;
	reg			r_dummy_done;
	always @(posedge clk, posedge rst) begin
		if (rst) begin
			r_dummy_counter <= 4'h0;
			r_dummy_done <= 1'b0;
		end
		else begin
			if (r_setup_start) begin
				r_dummy_counter <= r_dummy_cycles;
				r_dummy_done <= 1'b0;
			end
			else if (r_mosifinish && `LATCHOUT_EDGE && (~r_dummy_done)) begin
				r_dummy_counter <= r_dummy_counter - 1'b1;
			end
			else if (r_dummy_counter == 0 && `LATCHIN_EDGE) begin
				//must hold at 0 implicit r_q<=r_q
				//or implement dummy_done as wire for less delay?
				r_dummy_done <= 1'b1;
			end
		end
	end
	
	//Drive miso
	always @(posedge clk, posedge rst) begin
		if (rst) begin
			r_misodata <= 32'd0;
			r_misocounter <= 7'd0;
			r_misofinish <= 1'b0;
		end else begin
			if(`LATCHIN_EDGE && r_sclk_out_en && (r_mosifinish) && (r_dummy_done)) begin
				//r_misodata[r_misocounter] <= miso;
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
				
                if (r_misocounter == r_misoctrstop) begin
					r_misocounter <= 7'd0; 
					r_misofinish <= 1'b1;
				end
			end
			if (r_setup_rst) begin
				r_misofinish <= 1'b0;
                r_misodata <= 0;
			end
		end
	end

	
	//Drive validflag_out to make as pulse
	always @(posedge rst, negedge sclk) begin
		if(rst) begin
			validflag_out <= 1'b0;
		end else if (r_misofinish) begin
			validflag_out <= 1'b1;
		end else if (r_validoutHold == 2'b00) begin
			validflag_out <= 1'b0;
		end	
	end
	
	//Drive validflag_out to make as pulse
	//Synchro it to which clk?
	always @(posedge rst, negedge sclk) begin//allow more clks for polling? yes it's needed, but exactly how many?
		if (rst) begin 
			r_validoutHold <= 2'b10;
		end else begin
			if (validflag_out == 1'b1) begin	
				r_validoutHold <= r_validoutHold - 1'b1;
				if (r_validoutHold == 2'b00) begin
					r_validoutHold <= 2'b10;
				end
			end
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
			r_expct_answer <= 1'b0;
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
								r_expct_answer <= 1'b0;
								r_sclk_edges <= {w_commdcycles, 1'b0};
							end
						3'b001: begin//command + answer
								r_counterstop <= 8'd8;//Parameterize
								r_expct_answer <= 1'b1;
								r_misoctrstop <= w_misocycles - 1'b1;
								r_sclk_edges <= {w_commdcycles + w_misocycles, 1'b0};
							end
						3'b010: begin//command + address + answer (+dummy cycles)
								r_counterstop <= 8'd8 + (r_4byteaddr_on? 8'd32:8'd24);
								r_expct_answer <= 1'b1;
								r_misoctrstop <= w_misocycles - 1'b1;
								r_sclk_edges <= {w_commdcycles + w_addrcycles + r_dummy_cycles + w_misocycles, 1'b0};
							end
						3'b011:	begin//command + data_in
								r_counterstop <= 8'd8 + r_ndatatxbits;
								r_expct_answer <= 1'b0;
								r_sclk_edges <= {w_commdcycles + w_datatxcycles,1'b0};
							end
						3'b100: begin//command + address + data_in (+dummy cycles)
								r_counterstop <= 8'd8 + (r_4byteaddr_on? 8'd32:8'd24) + r_ndatatxbits;
								r_expct_answer <= 1'b0;
								r_sclk_edges <= {w_commdcycles + w_addrcycles + r_dummy_cycles + w_datatxcycles,1'b0};
							end
						3'b101: begin//command+address
								r_counterstop <= 8'd8 + (r_4byteaddr_on? 8'd32:8'd24);
								r_expct_answer <= 1'b0;
								r_sclk_edges <= {w_commdcycles + w_addrcycles,1'b0};
							end
					default:	begin//Add code for XIP mode
								r_counterstop <= 8'd8;
								r_expct_answer <= 1'b0;//TODO other control signals default
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
			data_out <= 0;
		end else begin
			
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
					if(r_transfers_done) begin
						r_ss_n <= 1'b1;
						r_sclk_out_en <= 1'b0;
						data_out <= r_misodata;
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
