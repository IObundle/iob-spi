
`timescale 1ns / 1ps
`include "rcntlr_defines.v"

module register_bank_tb ();

  reg		    clk;
  reg  	            rst;
  reg                wr;
  reg      [`LOG_N_REGISTERS-1:0]address;     
  reg      [`DATA_WIDTH-1:0]data_in;   
  wire    [2**`LOG_N_REGISTERS * `DATA_WIDTH - 1 :0]chip_out;    
  wire    [`DATA_WIDTH-1:0] data_out;
  integer i;
  parameter clk_per= 100;

  
  register_bank  uut(
     .clk    (clk),
     .rst    (rst),
     .wr    (wr),
     .address (address[`LOG_N_REGISTERS-1:0]),
     .data_in (data_in[`DATA_WIDTH-1:0]),
     .chip_out (chip_out[2**`LOG_N_REGISTERS * `DATA_WIDTH - 1 :0]),
     .data_out (data_out[`DATA_WIDTH-1:0])
);

  initial begin
     $dumpfile("register_bank.vcd");
     $dumpvars();
     rst = 1;
     clk = 1;
     wr = 0;
     address <= 5'd0;
     data_in <= 8'd0;
     #(clk_per) rst=0;
     wr = 1;

    for (i=0 ; i<32 ; i=i+1) begin
        #(clk_per) 
        address <= address + 1;
        data_in <= data_in + 1;
    end
    #(clk_per);
    address <= 5'd0;
    wr = 0;

    #(clk_per*6)

    for (i=0 ; i<32 ; i=i+1) begin
        #(clk_per) 
        address <= address + 1;
        if (i==31) address <= 5'd0;
    end
    #(clk_per*6) rst=1;
    #(clk_per) rst=0;
    #(clk_per*6) ; 
    #(clk_per) $finish;

  end

  always
     #(clk_per/2) clk = ~clk;

endmodule
