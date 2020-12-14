
`timescale 1ns / 1ps
`define SPI_DATA_W 32 
`define SPI_COM_W 8
`define SPI_CTYP_W 3
`define SPI_ADDR_W 24

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
	output reg							validflag_out,
	output reg							tready,

	//SPI INTERFACE
	output  	sclk,
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
	reg [6:0]	r_counterstop;

	//MOSI controller signals
	reg 		r_mosiready;
	reg 		r_mosibusy;
	reg [6:0]	r_mosicounter;
	wire [63:0]	str2send;//Parameterize

	//MISO controller signals
	reg						r_misostart;
	reg 					r_misobusy;
	reg [4:0]				r_misocounter;
	reg [`SPI_DATA_W-1:0]	r_misodata;
	reg 					r_misovalid;
	
	//Synchronization signals
	wire onOperation;
	reg  startOperation; //new
	reg	 r_expct_answer;	
	//
	reg	 r_validedge = 1'b0;
	reg [1:0] r_validoutHold = 2'b10;

	//CLK generation signals
	reg [3:0] clk_counter = 4'd0;
	parameter DIVISOR = 4'd2;
	
	//Generate sclk by clock division
	always @(posedge clk) begin //rst block ?
		clk_counter <= clk_counter + 4'd1;
		if(clk_counter >= (DIVISOR-1)) begin
			clk_counter <= 4'd0;
		end
	end
	assign sclk = (clk_counter<DIVISOR/2)?1'b0:1'b1;
	
	//Receive data to transfer from upperlevel controller
	always @(posedge clk, posedge rst) begin
		if (rst) begin
			r_datain <= `SPI_DATA_W'b0;
			r_address <= `SPI_ADDR_W'b0;
			r_command <= `SPI_COM_W'b0;
			r_commandtype <= `SPI_CTYP_W'b111;
		end else begin
			if (r_validedge) begin
				r_datain <= data_in;
				r_address <= address;
				r_command <= command;
				r_commandtype <= commtype;
			end
		end
	end

	always @(posedge rst, posedge clk) begin
		if (rst) begin
			r_validedge <= 1'b0;
		end else if(r_validedge) begin
			r_validedge <= 1'b0;
		end else if (validflag) begin 
			r_validedge <= 1'b1;
		end
	end

	//r_mosiready
	always @(posedge rst, posedge clk) begin
		if (rst) begin
			r_mosiready <= 1'b0;
		end else if (r_validedge) begin
			r_mosiready <= 1'b1;
		end else if (r_mosibusy) begin
			r_mosiready <= 1'b0;
		end
	end
	
	//MOSI 
	//Send a byte through mosi line
	always @(negedge sclk, posedge rst) begin
		if (rst) begin
			mosi <= 1'b0;	
			ss <= 1'b1;	
			r_mosibusy <= 1'b0;
			r_mosicounter <= 7'd63;//Changed to accomodate WRITE
		end else begin
			if (r_mosiready | r_mosibusy) begin
				//Drive ss low to start transaction
				ss <= 1'b0;
				r_mosibusy <= 1'b1;

				if(r_mosibusy) begin//one-cycle delay
					mosi <= str2send[r_mosicounter];
					r_mosicounter <= r_mosicounter - 7'd1;
					if (r_mosicounter == r_counterstop) begin
						//Simple switch implementation for READ or WRITE
						//operations, upgrade later
						if (r_expct_answer) begin
							r_mosibusy <= 1'b0;
							r_mosicounter <= 7'd63;
						end else begin
							r_mosibusy <= 1'b0;
							r_mosicounter <= 7'd63;
						end
					//	ss <= 1'b1;
					//	mosicounter reinitialized TODO
					end else if(r_mosicounter == 6'd0) begin
						r_mosibusy <= 1'b0;	
					end
				end
			end else begin
				if (r_misostart | r_misobusy) begin
					ss <= 1'b0; //Keep low to receive on miso		
				end else begin
					ss <= 1'b1;
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
		end else if (r_misocounter == 5'b0) begin
			r_misobusy <= 1'b0;
		end
	end
	//MISO
	//TODO keep ss low
	always @(posedge sclk, posedge rst) begin
		if (rst) begin
			r_misocounter <= 5'd31;
			r_misodata <= 32'hffffffff; //Default no data on flash mem
		end else begin
			if (r_misobusy) begin
				
				//Get miso line data
				r_misodata[r_misocounter] <= miso;
				r_misocounter <= r_misocounter - 5'd1;

				if (r_misocounter == 5'b0) begin
					r_misocounter <= 5'd31;
				end
			end
		end
	end
	
	//Drive module output data_out
	always @(negedge sclk, posedge rst) begin
		if (rst) begin
			r_misovalid <= 1'b0;
			data_out <= `SPI_DATA_W'd0;
		end	else if (r_misovalid) begin //Data will be available on data_out after sclk_per/2
				data_out <= r_misodata;
				r_misovalid <= 1'b0;
		end else if (r_misobusy && r_misocounter == 5'b0) begin
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
				r_validoutHold <= r_validoutHold - 2'd1;
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
	assign str2send = (r_commandtype == 3'b011) ? {r_command, data_in, {24{1'b0}}}: {r_command, r_address, r_datain};//Parameterize
	//Master State Machine
	always @(posedge rst, posedge clk) begin
		if (rst) begin
			r_expct_answer <= 1'b0;
			r_counterstop <= 7'd56;
		end else begin
			case(r_commandtype)
				3'b000:	begin//Only command
						r_counterstop <= 7'd56;
						r_expct_answer <= 1'b0;
					end
				3'b001: begin//command + answer
						r_counterstop <= 7'd56;
						r_expct_answer <= 1'b1;
					end
				3'b010: begin//command + address + answer
						r_counterstop <= 7'd48;
						r_expct_answer <= 1'b1;
					end
				3'b011:	begin//command + data_in
						r_counterstop <= 7'd24;
						r_expct_answer <= 1'b0;
					end
				3'b100: begin//command + address + data_in
						r_counterstop <= 7'd0;
						r_expct_answer <= 1'b0;
					end
				3'b101: begin//command+address
						r_counterstop <= 7'd32;
						r_expct_answer <= 1'b0;
					end
			default:	begin
						r_counterstop <= 7'd32;
						r_expct_answer <= 1'b0;
					end
			endcase
		end
	end
endmodule
