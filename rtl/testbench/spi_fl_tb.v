`timescale 1ns / 1 ps

module spi_tb;
	
	parameter clk_per = 20;

	reg rst;
	reg clk;

	reg miso;
	wire mosi;
	wire ss;
	wire sclk;
	
	reg [7:0] data_in;
	wire [7:0] data_out;
	reg [23:0] address;
	reg [7:0] command;
	reg validflag; //check later
	wire validflag_out; //check
	wire tready;
	reg tofrom_fl;

	//Controller signals
	
	// UUT Instantiation
	spi_master_fl spi_m (
			.clk		(clk),
			.rst		(rst),

			//SPI
			.ss			(ss),
			.mosi		(mosi),
			.sclk		(sclk),
			.miso		(miso),
			
			//Controller
			.data_in	(data_in),
			.data_out	(data_out),
			.address	(address),
			.command	(command),
			.validflag	(validflag),
			.validflag_out	(validflag_out),
			.tready		(tready),
			.tofrom_fl	(tofrom_fl)
			);
			

	//Process
	initial begin
		$dumpfile("spi_fl_tb.vcd");
		$dumpvars();
		
		//Clks and reset
		rst = 1;
		clk = 1;

		//Deassert rst
		#(4*clk_per+1) rst = 0;

	end

	//Master Process
	initial begin
		#100
		data_in=8'h5A;
		command=8'h55;
		address=24'h555555;
		tofrom_fl=1'b1;

		#50
		validflag=1'b1;
		#20
		validflag=1'b0;
		#1330 //Drive miso
		miso <= 1'b1; #40;
		miso <= 1'b0; #40;
		miso <= 1'b1; #40;
		miso <= 1'b1; #40;
		miso <= 1'b1; #40;
		miso <= 1'b1; #40;
		miso <= 1'b0; #40;
		miso <= 1'b1; #40;
		#100 $finish;
	end

	//CLK driving
	always
		#(clk_per/2) clk=~clk;
endmodule
