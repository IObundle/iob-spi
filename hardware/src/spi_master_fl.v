`timescale 1ns / 1ps
`include "iob_lib.vh"
`define SPI_DATA_W 32 
`define SPI_COM_W 8
`define SPI_CTYP_W 3
`define SPI_ADDR_W 32
`define SPI_DATA_MINW 8

module spi_master_fl(
	
	//CONTROLLER INTERFACE
	input		clk,
	input 		rst,

	//CONTROLLER FROM CPU
	input [`SPI_DATA_W-1:0]				data_in,
	output reg [`SPI_DATA_W-1:0]		data_out,
	input [`SPI_ADDR_W-1:0]				address,
	input [`SPI_COM_W-1:0]				command,
	input 								validflag,
	input [`SPI_CTYP_W-1:0]				commtype,
	input [6:0]							nmiso_bits,	
	output reg							validflag_out,
	output reg							tready,

	//SPI INTERFACE
	input	  	sclk,
	output reg	ss,
	output reg	mosi,
	input		miso
);

	//Register TX data, address, command
	reg [`SPI_DATA_W-1:0]	r_datain;
	reg [`SPI_ADDR_W-1:0]	r_address;
	reg [`SPI_COM_W-1:0]	r_command;

	//Extra reg for mode controlling
	reg	[2:0]	r_commandtype;
	reg			r_4byteaddr_on = 1'b0;
	reg [7:0]	r_counterstop;
	reg [6:0]	r_misoctrstop;

	//MOSI controller signals
	reg 		r_mosiready;
	reg 		r_mosibusy;
	reg [7:0]	r_mosicounter;
	//wire [63:0]	str2send;//Parameterize
	reg [71:0]	r_str2sendbuild;

	//MISO controller signals
	reg						r_misostart;
	reg 					r_misobusy;
	reg [6:0]				r_misocounter;
	reg [`SPI_DATA_W-1:0]	r_misodata;
	reg 					r_misovalid;
	reg	[6:0]				r_nmisobits;
	reg						r_misofinish;
	
	//Synchronization signals
	wire onOperation;
	reg  startOperation = 1'b0; //new
	reg	 r_expct_answer = 1'b0;	
	reg  r_inputread = 1'b0;

	reg [`SPI_DATA_W-1:0] dout_sync [1:0];

	//
	reg	 r_validedge = 1'b0;
	reg [1:0] r_validoutHold = 2'b10;

	//CLK generation signals
	reg [3:0] clk_counter = 4'd0;
	parameter DIVISOR = 4'd2;
	
	//Generate sclk by clock division
	/*always @(posedge clk) begin //rst block ?
		clk_counter <= clk_counter + 1'b1;
		if(clk_counter >= (DIVISOR-1)) begin
			clk_counter <= 4'd0;
		end
	end
	assign sclk = (clk_counter<DIVISOR/2)?1'b0:1'b1;*/
	
	//Receive data to transfer from upperlevel controller
	always @(posedge clk, posedge rst) begin
		if (rst) begin
			r_datain <= `SPI_DATA_W'b0;
			r_address <= `SPI_ADDR_W'b0;
			r_command <= `SPI_COM_W'b0;
			r_commandtype <= `SPI_CTYP_W'b111;
			r_inputread <= 1'b0;
		end else begin
			if (r_validedge) begin
				r_datain <= data_in;
				r_address <= address;
				r_command <= command;
				r_commandtype <= commtype;
				r_nmisobits <= nmiso_bits;
				r_inputread <= 1'b1;
			end
			else if (~validflag) begin
				r_inputread <= 1'b0;
			end
		end
	end

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

	//Build r_str2sendbuild
	always @(posedge rst, posedge clk) begin
		if (rst) begin
			r_str2sendbuild <= 72'h0;
		end else begin
			if (~r_4byteaddr_on) begin
				r_str2sendbuild <= (r_commandtype == 3'b011) ? {r_command, data_in, {32{1'b0}}}: {r_command, r_address[23:0], r_datain, {8{1'b0}}};
			end else begin
				r_str2sendbuild <= (r_commandtype == 3'b011) ? {r_command, data_in, {32{1'b0}}}: {r_command, r_address, r_datain};
			end
		end
	end

	//r_str2send synchronization
	reg [71:0]			r_spistr2send [1:0];
	wire 				synchrocomplete;
	always @(posedge sclk) begin
		r_spistr2send[0] <= r_str2sendbuild;
		r_spistr2send[1] <= r_spistr2send[0];
	end
	assign synchrocomplete = |(r_spistr2send[1]);

	//mosiready synchronization
	reg	[4:0]				r_validedgesync=5'd0;
	always @(posedge sclk, posedge r_validedge) begin
		if (r_validedge) begin
			r_validedgesync <= 5'h1f;
		end else begin
			r_validedgesync <= {r_validedgesync[3], r_validedgesync[2], r_validedgesync[1], r_validedgesync[0],1'b0};
		end
	end
	//r_mosiready
	wire 	mosistart;
	assign mosistart = (|r_validedgesync) & synchrocomplete;
	always @(posedge rst, posedge sclk, posedge synchrocomplete) begin
		if (rst) begin
			r_mosiready <= 1'b0;
		end else if (mosistart) begin//check
			r_mosiready <= 1'b1;
		end else if (r_mosibusy) begin
			r_mosiready <= 1'b0;
		end
	end
	
	//Drive ss
	//wire		synchro_ss;
	assign synchro_ss = (r_validedgesync[4] & r_validedgesync[3] & (~r_validedgesync[2]) & (~r_validedgesync[1]) & (~r_validedgesync[0])) ;
	always @(negedge sclk, posedge rst) begin
		if (rst)
			ss <= 1'b1;
		else if (r_mosiready | r_mosibusy | r_misostart | r_misobusy)
			ss <= 1'b0;
		else
			ss <= 1'b1;
	end

	//MOSI CONTROLS 
	//Send a byte through mosi line
	always @(negedge sclk, posedge rst) begin
		if (rst) begin
			mosi <= 1'b0;	
			r_mosibusy <= 1'b0;
			r_mosicounter <= 8'd71;//Changed to accomodate WRITE
		end 
		else begin
			if (r_mosiready | r_mosibusy) begin
				r_mosibusy <= 1'b1;

				if(r_mosibusy) begin//one-cycle delay
					mosi <= r_spistr2send[1][r_mosicounter];
					r_mosicounter <= r_mosicounter - 1'b1;
					if (r_mosicounter == r_counterstop) begin
						if (r_expct_answer) begin
							r_mosibusy <= 1'b0;
							r_mosicounter <= 8'd71;
						end else begin
							r_mosibusy <= 1'b0;
							r_mosicounter <= 8'd71;
						end
					end 
					else if(r_mosicounter == 8'd0) begin
						r_mosibusy <= 1'b0;	
					end
				end
			end 
		end
	end
	
	//MISO synchronization
	always @(negedge sclk, posedge rst) begin
		if (rst) begin
			r_misostart <= 1'b0;
			r_misobusy <= 1'b0;
		end else if (r_misostart) begin
			r_misobusy <= 1'b1;
			r_misostart <= 1'b0;
		end else if (r_mosibusy && (r_mosicounter==r_counterstop) &&r_expct_answer) begin
			r_misostart <= 1'b1; //Assumes reply on miso line right after mosi busy
		end else if (r_misofinish) begin
			r_misobusy <= 1'b0;
		end
	end
	//MISO
	//TODO keep ss low
	always @(posedge sclk, posedge rst) begin
		if (rst) begin
			r_misocounter <= 7'd0;
			r_misodata <= 32'h0; //Default no data on flash mem
			r_misofinish <= 1'b0;
		end else begin
			if (r_misobusy) begin
				
				//Get miso line data
				r_misodata[r_misocounter] <= miso;
				r_misocounter <= r_misocounter + 1'b1;
				r_misofinish <= 1'b0;

				if (r_misocounter == r_misoctrstop) begin
					r_misocounter <= 7'd0;
					r_misofinish <= 1'b1;
				end
			end
			else if (r_misovalid) begin
				r_misofinish <= 1'b0;
			end
			else if (r_validedgesync) begin
				r_misodata <= 0;
			end
		end
	end

	//Data_out synchronizer
	always @(posedge clk, posedge rst) begin
		if (rst) begin
			data_out <= `SPI_DATA_W'd0;
			dout_sync[0] <= `SPI_DATA_W'd0;
			dout_sync[1] <= `SPI_DATA_W'd0;
		end
		else begin
			dout_sync[0] <= r_misodata;
			dout_sync[1] <= dout_sync[0];
		end
	end 

	always @(dout_sync[1]) begin
		data_out <= dout_sync[1];
	end

	
	//Drive module output data_out
	always @(negedge sclk, posedge rst) begin
		if (rst) begin
			r_misovalid <= 1'b0;
			//data_out <= `SPI_DATA_W'd0;
		end	else if (r_misovalid) begin //Data will be available on data_out after sclk_per/2
				//data_out <= r_misodata;
				r_misovalid <= 1'b0;
		end else if (r_misobusy && r_misofinish) begin
				r_misovalid <= 1'b1;
		end
	end
	
	//Drive validflag_out to make as pulse
	always @(posedge rst, negedge sclk) begin
		if(rst) begin
			validflag_out <= 1'b0;
		end else if (r_misovalid) begin
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
	
	//Drive tready
	//Extensible to allow more parallelization
	//Eg.: drive tready after mosi sent
	//Same behavior as ss for now
	//Synchronizing on sclk may cause excessive delay for next command from controller
	assign onOperation = r_mosiready | r_mosibusy | r_misostart | r_misobusy;//Reuse
	always @(negedge sclk, posedge rst) begin
		if (rst) begin
			tready <= 1'b1;
		end else begin
			//tready <= ss;
			tready <= ~onOperation;
		end
	end

	//MUX
	//Master State Machine
	always @(posedge rst, posedge clk) begin
		if (rst) begin
			r_expct_answer <= 1'b0;
			r_counterstop <= 8'd64;
			r_misoctrstop <= 7'd7;
		end else begin
			case(r_commandtype)
				3'b000:	begin//Only command
						r_counterstop <= 8'd64;
						r_expct_answer <= 1'b0;
					end
				3'b001: begin//command + answer
						r_counterstop <= 8'd64;
						r_expct_answer <= 1'b1;
						r_misoctrstop <= r_nmisobits - 1;
					end
				3'b010: begin//command + address + answer
						r_counterstop <= (~r_4byteaddr_on) ? 8'd40: 8'd32;
						r_expct_answer <= 1'b1;
						r_misoctrstop <= r_nmisobits - 1;
					end
				3'b011:	begin//command + data_in
						r_counterstop <= 8'd32;
						r_expct_answer <= 1'b0;
					end
				3'b100: begin//command + address + data_in
						r_counterstop <= (~r_4byteaddr_on) ? 8'd8: 8'd0;
						r_expct_answer <= 1'b0;
					end
				3'b101: begin//command+address
						r_counterstop <= (~r_4byteaddr_on) ? 8'd40: 8'd32;
						r_expct_answer <= 1'b0;
					end
			default:	begin
						r_counterstop <= 8'd32;
						r_expct_answer <= 1'b0;
					end
			endcase
		end
	end
endmodule
