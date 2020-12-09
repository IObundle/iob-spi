//
//	SPI FLASH controller
//

iob_spi_master_fl spifl
	(
	 .clk(clk),
	 .rst(reset),
	 
	 //cpu interface
	 .valid(slaves_req[`valid(`SPI)]),
     .address(slaves_req[`address(`SPI,`FL_ADDR_W+2)-2]),
     .wdata(slaves_req[`wdata(`SPI)-(`DATA_W-`FL_WDATA_W)]),
     .wstrb(slaves_req[`wstrb(`SPI)]),
     .rdata(slaves_resp[`rdata(`SPI)]),
     .ready(slaves_resp[`ready(`SPI)])	

	);
