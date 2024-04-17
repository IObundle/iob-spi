`timescale 1ns / 1 ps

module iob_spi_tb;

  parameter clk_per = 20;
  parameter sclk_per = 40;

  reg rst;
  reg clk;

  wire miso;
  wire mosi;
  wire hold_n;
  wire wp_n;
  wire ss;
  reg sclk;

  reg [31:0] data_in;
  wire [31:0] data_out;
  reg [31:0] address;
  reg [7:0] command;
  reg [2:0] commtype;
  reg [6:0] nmiso_bits;
  reg [3:0] dummy_cycles;
  reg [9:0] frame_struct;
  reg [1:0] xipbit_en;
  reg [1:0] spimode;
  reg validflag;
  wire tready;
  reg tofrom_fl;
  reg fourbyteaddr_on;
  reg dtr_en;

  integer i, fd;
  integer failed = 0;
  reg [31:0]    mem;

  //Controller signals

  // UUT Instantiation
  spi_master_fl #(
      .CPOL(1),
      .CPHA(1)
  ) spi_m (
      .clk(clk),
      .rst(rst),

      //SPI
      .ss      (ss),
      .mosi_dq0(mosi),
      .sclk    (sclk),
      .miso_dq1(miso),
      .hold_n_dq3(hold_n),
      .wp_n_dq2(wp_n),

      //Controller
      .data_in        (data_in),
      .data_out       (data_out),
      .address        (address),
      .command        (command),
      .commtype       (commtype),
      .ndata_bits     (nmiso_bits),
      .frame_struct   (frame_struct),
      .dtr_en         (dtr_en),
      .xipbit_en      (xipbit_en),
      .dummy_cycles   (dummy_cycles),
      .spimode        (spimode),
      .fourbyteaddr_on(fourbyteaddr_on),
      .validflag      (validflag),
      .tready         (tready)
  );

  reg sipo_arst;
  wire [64-1:0] sipo_1_out;
  wire [4*64-1:0] sipo_4_out;

  // Track SPI output
  sipo_nbits #(
        .SERIAL_W(1),
        .PARALLEL_W(64)
  ) sipo_1bit (
        .clk(sclk),
        .arst(sipo_arst),
        .en(~ss),
        .serial_in(mosi),
        .parallel_out(sipo_1_out)
  );

  sipo_nbits #(
        .SERIAL_W(4),
        .PARALLEL_W(64*4)
  ) sipo_4bit (
        .clk(sclk),
        .arst(sipo_arst),
        .en(~ss),
        .serial_in({hold_n, wp_n, miso, mosi}),
        .parallel_out(sipo_4_out)
  );


  //Process
  initial begin
    $dumpfile("iob_spi_tb.vcd");
    $dumpvars();

    //Clks and reset
    rst = 1;
    clk = 1;
    //sclk = 1;
    sipo_arst = 1;

    //Deassert rst
    #(4 * clk_per + 1) rst = 0;

  end

  //Master Process
  initial begin
    #100 fourbyteaddr_on = 1'b1;

    $display("Test command 0.");
    spimode = 2'b00;
    data_in=32'haabbccdd;
    command=8'h66;
    address=32'haa5a5a11;
    commtype = 3'b001;
    dtr_en = 0;
    nmiso_bits = 7'd16;
    frame_struct = 10'h084;
    xipbit_en = 2'b00;
    dummy_cycles = 4'd0;
    mem    = 32'hA0A0A0A3;

    sipo_arst = 0;

    #50 validflag = 1'b1;
    #20 validflag = 1'b0;
    #370  // Drive miso
    for (i = 15; i >= 0; i = i - 1) begin
      #40;
      //miso <= mem[i];
    end
    //#3000

    wait (tready);

    // check SPI output
    if (sipo_1_out[16-1-:8] != command) begin
        $display("\tTest failed: expected command : %x\tgot %x", command, sipo_1_out[16-1-:8]);
        failed = 1;
    end else begin
        $display("\tTest passed");
    end

    sipo_arst = 1;

    #120 $display("Test command 1.");
    spimode = 2'b11;
    data_in=32'haabbccdd;
    command=8'h6b;
    address=24'h555555;
    commtype = 3'b100;
    frame_struct = 10'h260;
    xipbit_en = 2'b00;
    nmiso_bits = 7'd32;
    dummy_cycles = 4'd0;
    dtr_en = 0;
    mem    = 32'hA0A0A0A3;

    sipo_arst = 0;

    #50 validflag = 1'b1;
    #20 validflag = 1'b0;

    #100 wait (tready);

    // check SPI output
    $display("\tTODO: check SPI output");
    // if (sipo_1_out[26-1-:8] != command) begin
    //     $display("\tTest failed: expected: %x\tgot %x", command, sipo_1_out[16-1-:8]);
    //     failed = 1;
    // end else begin
    //     $display("\tTest passed");
    // end

    sipo_arst = 1;

    #120 $display("Test command 2.");
    spimode = 2'b10;
    data_in=8'h5A;
    command=8'h0b;
    address=24'h555555;
    commtype = 3'b110;
    frame_struct = 10'h100;
    xipbit_en = 2'b01;
    nmiso_bits = 7'd16;
    dummy_cycles = 4'd10;
    dtr_en = 0;
    mem    = 32'hA0A0A0A3;

    sipo_arst = 0;

    #50 validflag = 1'b1;
    #20 validflag = 1'b0;
    //#500
    #100 wait (tready);

    // check SPI output
    if (sipo_4_out[(nmiso_bits+4*dummy_cycles+32)-1-:32] != address) begin
        $display("\tTest failed: expected address: %x\tgot %x", address, sipo_4_out[(nmiso_bits+4*dummy_cycles+32)-1-:32]);
        failed = 1;
    end else begin
        $display("\tTest passed");
    end

    sipo_arst = 1;

    #120 $display("Test command 3.");
    spimode = 2'b00;
    data_in=8'h5A;
    command=8'h6D;
    address=24'h555555;
    commtype = 3'b010;
    frame_struct = 10'h008;
    xipbit_en = 2'b00;
    nmiso_bits = 7'd16;
    dtr_en = 1;
    dummy_cycles = 4'd10;
    mem    = 32'hA0A0A0A3;

    sipo_arst = 0;

    #50 validflag = 1'b1;
    #20 validflag = 1'b0;
    #100 wait (tready);

    // check SPI output
    // SPI Cycles = 8 (command)
    //          + 32/2 (address in DTR)
    //          + 10 (dummy cycles)
    //          + 16/4/2 (nmiso_bits in QUADOUT mode in DTR)
    if (sipo_1_out[(8+dummy_cycles+32/2+((nmiso_bits/4)/2))-1-:8] != command) begin
        $display("\tTest failed: expected command: %x\tgot %x", command, sipo_1_out[(36)-1-:8]);
        failed = 1;
    end else begin
        $display("\tTest passed");
    end
    // TODO: check address in DTR

    fd = $fopen("test.log", "w");
    if (failed == 1) begin
        $display("TEST FAILED!");
        $fdisplay(fd, "Test failed!");
    end else begin
        $display("TEST PASSED!");
        $fdisplay(fd, "Test passed!");
    end
    $fclose(fd);
    $finish();
  end

  //CLK driving
  always #(clk_per / 2) clk = ~clk;

endmodule

module sipo_nbits #(
    parameter SERIAL_W= 1,
    parameter PARALLEL_W = 32
) (
    input clk,
    input arst,
    input en,
    input [SERIAL_W-1:0] serial_in,
    output [PARALLEL_W-1:0] parallel_out
);

    reg [PARALLEL_W-1:0] parallel_out_reg;
    wire [SERIAL_W-1:0] serial_in_int;

    assign serial_in_int = (serial_in === {SERIAL_W{1'bz}}) ? {SERIAL_W{1'b0}} : serial_in;

    // CPOL = 0, CPHA = 0
    // CPOL = 1, CPHA = 1
    // both cases sample data on rising edge
    always @(posedge clk, posedge arst) begin
        if (arst) begin
            parallel_out_reg <= 0;
        end else begin
            if (en) begin
                parallel_out_reg <= {parallel_out_reg[PARALLEL_W-SERIAL_W-1:0], serial_in_int};
            end
        end
    end

    assign parallel_out = parallel_out_reg;

endmodule
