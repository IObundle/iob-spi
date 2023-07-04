//
//    SPI FLASH controller
//

iob_spi_master_fl spifl
    (
     .clk(clk),
     .rst(reset),

     //spi flash interface
     .SCLK(spi_outsclk),
     .SS(spi_ss),
     .MOSI(spi_mosi),
     .WP_N(spi_wpn),
     .HOLD_N(spi_holdn),
     .MISO(spi_miso),

`ifdef RUN_FLASH
     //cache interface
     .valid_cache(mem_valid_flash),
     .address_cache(mem_addr_flash),
     .wdata_cache(mem_wdata_flash),
     .wstrb_cache(mem_wstrb_flash),
     .rdata_cache(mem_rdata_flash),
     .ready_cache(mem_ready_flash),
`endif

     //cpu interface
     .valid(slaves_req[`valid(`SPI)]),
     .address(slaves_req[`address(`SPI,`FL_ADDR_W+2)-2]),
     .wdata(slaves_req[`wdata(`SPI)-(`DATA_W-`FL_WDATA_W)]),
     .wstrb(slaves_req[`wstrb(`SPI)]),
     .rdata(slaves_resp[`rdata(`SPI)]),
     .ready(slaves_resp[`ready(`SPI)])
    );
