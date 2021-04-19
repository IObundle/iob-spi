`timescale 1ns / 1ps

`define SINGLEMODE0 2'b00
`define SINGLEMODE1 2'b11
`define DUALMODE 2'b01
`define QUADMODE 2'b10
`define SINGLEMODEON (spimode==`SINGLEMODE0 || spimode==`SINGLEMODE1)
`define DUALMODEON (spimode==`DUALMODE)
`define QUADMODEON (spimode==`QUADMODE)

module latchspi
(
    input clk,
    input rst,

    output [3:0] data_tx,
    input [3:0] data_rx,
    input sclk_en,
    input latchin_en,
    input latchout_en,
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
    input [9:0] txcntmarks [2:0],
    input [1:0] spimode,
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
    
    reg [71:0] r_str2sendbuild;

	reg [31:0] r_misodata;
	reg [6:0] r_misocounter;

    //Load tx data into array
    always @(posedge clk, posedge rst) begin
        if (rst)
            r_str2sendbuild <= 0;
        else begin
           if (loadtxdata_en) //pulse signal, 1 clk cycle
               r_str2sendbuild <= txstr;
        end
    end
    
    //assign to output
    assign data_tx = r_mosi;
    assign mosicounter = r_mosicounter;
    assign read_data = r_misodata;
    assign mosifinish = r_mosifinish;
    assign sending_done = r_sending_done;

	always @(posedge clk, posedge rst) begin
		if (rst) begin
			//mosi <= 1'b0;
            r_mosi <= 4'h0;
			r_mosicounter <= 8'd0;
			r_mosifinish <= 1'b0;
			r_sending_done <= 1'b0;
            r_txindexer <= 8'd71;
		end else begin
			//if(r_transfer_start) begin end
			if (latchout_en && sclk_en && (~r_mosifinish)) begin
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
            else if(xipbit_en[1] && w_xipbit_phase) begin//Drive xip confirmation bit
                r_mosi[0] <= xipbit_en[0];
            end
            if(r_mosicounter == mosistop_cnt) begin
                r_mosicounter <= 8'd0;
                r_txindexer <= 8'd71;
                r_sending_done <= 1'b1;
            end
			if (r_sending_done && latchin_en) begin
				r_mosifinish <= 1'b1;
			end
			if (setup_rst) begin
				r_mosifinish <= 1'b0;
				r_sending_done <= 1'b0;
			end
		end
	end

	//Go through the dummy cycles
	reg [3:0]		r_dummy_counter;
	reg			r_dummy_done;
    reg         r_xipbit_phase;
    wire        w_xipbit_phase;
    wire        dummy_count_en;
    assign dummy_count_en = r_mosifinish && latchout_en && (~r_dummy_done);
    //assign xipbit_phase = r_xipbit_phase;
    assign xipbit_phase = w_xipbit_phase;
	assign w_xipbit_phase = dummy_count_en & (r_dummy_counter==dummy_cycles);

	always @(posedge clk, posedge rst) begin
		if (rst) begin
			r_dummy_counter <= 4'h0;
			r_dummy_done <= 1'b0;
            r_xipbit_phase <= 1'b0;
		end
		else begin
			if (setup_rst) begin //previously setup_start, same behaviour
				r_dummy_counter <= dummy_cycles;
				r_dummy_done <= 1'b0;
                r_xipbit_phase <= 1'b0;
			end
			else if (dummy_count_en) begin
				r_dummy_counter <= r_dummy_counter - 1'b1;
                r_xipbit_phase <= (r_dummy_counter==dummy_cycles);
			end
			else if (r_dummy_counter == 0 && latchin_en) begin
				//must hold at 0 implicit r_q<=r_q
				//or implement dummy_done as wire for less delay?
				r_dummy_done <= 1'b1;
			end
		end
	end

	//Drive miso
    //Reverse endianness of misodata
    wire [31:0] w_misodatarev;
    assign w_misodatarev = {r_misodata[7:0], r_misodata[7:0], r_misodata[15:8], r_misodata[7:0], 
                                r_misodata[23:16], r_misodata[7:0], r_misodata[31:24], r_misodata[7:0]};
    assign read_datarev = w_misodatarev;
	always @(posedge clk, posedge rst) begin
		if (rst) begin
			r_misodata <= 32'd0;
			r_misocounter <= 7'd0;
		end else begin
			if(latchin_en && sclk_en && (r_mosifinish) && (r_dummy_done)) begin
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
			end
			if (setup_rst) begin
                r_misocounter <= 7'd0;
                r_misodata <= 0;
			end
		end
	end

    // Control lanes to use when on req
    //reg [9:0] txcntholder;
    wire [9:0] txcntholder = txcntmarks[nextcnt]; 
    reg [1:0] nextcnt;
    wire modeswitch_en = (`SINGLEMODEON && r_mosicounter == txcntholder[7:0] && r_mosicounter < mosistop_cnt); 
    wire [1:0] mode = txcntholder[9:8]; 
    wire quad_en_test = (mode == 2'b10) ? 1'b1 : 1'b0;
    wire dual_en_test = (mode == 2'b01) ? 1'b1 : 1'b0;

    assign dualtx_en = (`DUALMODEON) ? 1'b1 : (`QUADMODEON) ? 1'b0 : dual_en_test;
    assign quadtx_en = (`QUADMODEON) ? 1'b1 : (`DUALMODEON) ? 1'b0 : quad_en_test;

    /*always @(nextcnt) begin
        txcntholder = txcntmarks[nextcnt];
    end
    */
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            nextcnt <= 2'h0;
        end else begin
            if (modeswitch_en) begin
               nextcnt <= nextcnt + 1'b1;
            end
            if (setup_rst)
                nextcnt <= 0;
        end
    end

endmodule
