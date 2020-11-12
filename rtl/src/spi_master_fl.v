
`timescale 1ns / 1ps
`define SPI_DATA_W 8
`define SPI_COM_W 8
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

	//MOSI controller signals
	reg 		r_mosiready;
	reg 		r_mosibusy;
	reg [4:0]	r_mosicounter;
	wire [31:0]	str2send;

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
		end else begin
			if (validflag) begin
				r_datain <= data_in;
				r_address <= address;
				r_command <= command;
				r_mosiready <= 1'b1;
			end
		end
	end
	
	//MOSI 
	assign str2send = {r_command, r_address};
	//Send a byte through mosi line
	always @(negedge sclk, posedge rst) begin
		if (rst) begin
			ss <= 1'b1;	
			r_mosiready <= 1'b0;
			r_mosibusy <= 1'b0;
			r_mosicounter <= 5'd31;
		end else begin
			if (r_mosiready | r_mosibusy) begin
				//Drive ss low to start transaction
				ss <= 1'b0;
				r_mosibusy <= 1'b1;
				r_mosiready <= 1'b0;

				if(r_mosibusy) begin//one-cycle delay
					mosi <= str2send[r_mosicounter];
					r_mosicounter <= r_mosicounter - 5'd1;
					if (r_mosicounter == 5'd0) begin
						r_mosibusy <= 1'b0;
					//	ss <= 1'b1;
					end
				end
			end else begin
				ss <= 1'b1;
			end
		end
	end
	
	//MISO
	//TODO keep ss low
	/*always @(posedge sclk, posedge rst) begin
		if (rst) begin
		end else if
			miso <= ;
		end
	end*/
endmodule
