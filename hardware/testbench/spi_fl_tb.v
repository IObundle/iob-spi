`timescale 1ns / 1 ps

module spi_tb;
	
	parameter clk_per = 20;

	reg rst;
	reg clk;

	reg miso;
	wire mosi;
	wire ss;
	wire sclk;
	
	reg [31:0] data_in;
	wire [31:0] data_out;
	reg [23:0] address;
	reg [7:0] command;
	reg [2:0] commtype;
	reg validflag; //check later
	wire validflag_out; //check
	wire tready;
	reg tofrom_fl;

	integer i;
	reg [31:0]	mem;

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
			.commtype	(commtype),
			.validflag	(validflag),
			.validflag_out	(validflag_out),
			.tready		(tready)
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
		commtype = 3'b001;
		mem	= 32'hA0A0A0A3;

		#50
		validflag=1'b1;
		#20
		validflag=1'b0;
		#370 //Drive miso
		for(i=31;i>=0;i=i-1) begin
			miso <= mem[i]; #40;
		end
		#250 $finish;
	end

	//CLK driving
	always
		#(clk_per/2) clk=~clk;
endmodule
