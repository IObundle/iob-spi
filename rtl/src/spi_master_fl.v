
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
	output reg							validflag_out,
	output reg							tready,

	//MODE CONTROLLING SIGNALS
	input 								tofrom_fl,//0 from flash, 1 to flash

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
	reg			r_tofromfl;

	//MOSI controller signals
	reg 		r_mosiready;
	reg 		r_mosibusy;
	reg [5:0]	r_mosicounter;
	wire [39:0]	str2send;//Parameterize

	//MISO controller signals
	reg						r_misostart;
	reg 					r_misobusy;
	reg [2:0]				r_misocounter;//8 bits counter
	reg [`SPI_DATA_W-1:0]	r_misodata;
	reg 					r_misovalid;
	
	//Synchronization signals
	wire onOperation;

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
			r_tofromfl <= 1'b0; //Default READ
		end else begin
			if (validflag) begin
				r_datain <= data_in;
				r_address <= address;
				r_command <= command;
				r_mosiready <= 1'b1;
				r_tofromfl <= tofrom_fl;
			end
		end
	end
	
	//MOSI 
	assign str2send = {r_command, r_address, r_datain};//r_datain included for WRITE op
	//Send a byte through mosi line
	always @(negedge sclk, posedge rst) begin
		if (rst) begin
			ss <= 1'b1;	
			r_mosiready <= 1'b0;
			r_mosibusy <= 1'b0;
			r_mosicounter <= 6'd39;//Changed to accomodate WRITE
			r_misostart <= 1'b0;
			r_misobusy <= 1'b0;
		end else begin
			if (r_mosiready | r_mosibusy) begin
				//Drive ss low to start transaction
				ss <= 1'b0;
				r_mosibusy <= 1'b1;
				r_mosiready <= 1'b0;

				if(r_mosibusy) begin//one-cycle delay
					mosi <= str2send[r_mosicounter];
					r_mosicounter <= r_mosicounter - 6'd1;
					if (r_mosicounter == 6'd8) begin
						//Simple switch implementation for READ or WRITE
						//operations, upgrade later
						if (~r_tofromfl) begin
							r_mosibusy <= 1'b0;
							r_misostart <= 1'b1; //Assumes reply on miso line right after mosi busy
							r_mosicounter <= 6'd39;
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
			r_misobusy <= 1'b0;
		end else begin
			if (r_misostart) begin
				r_misobusy <= 1'b1;
				r_misostart <= 1'b0;
			end
		end
	end
	//MISO
	//TODO keep ss low
	always @(posedge sclk, posedge rst) begin
		if (rst) begin
			r_misocounter <= 3'b111;
			r_misovalid <= 1'b0;
		end else begin
			if (r_misobusy) begin
				
				//Get miso line data
				r_misodata[r_misocounter] <= miso;
				r_misocounter <= r_misocounter - 1;

				if (r_misocounter == 3'b0) begin
					r_misovalid <= 1'b1;
					r_misocounter <= 3'b111;
					r_misobusy <= 1'b0;
				end
			end
		end
	end
	
	//Drive module output data_out
	always @(negedge sclk, posedge rst) begin
		if (rst) begin
			r_misovalid <= 1'b0;
			validflag_out <= 1'b0;
		end	else begin 
			if (r_misovalid) begin //Data will be available on data_out after sclk_per/2
				data_out <= r_misodata;
				r_misovalid <= 1'b0;
				//TODO Drive valid data_out signal
				validflag_out <= 1'b1;
			end
		end
	end
	//Drive validflag_out to make as pulse
	//Synchro it to which clk?
	always @(posedge clk) begin//allow more clks for polling?
		if (validflag_out) begin
			validflag_out <= 1'b0;
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
endmodule
