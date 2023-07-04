        //CPU native interface
        input                           valid_cache,  //Native CPU interface valid signal
        input [`FLASH_CACHE_ADDR_W-1:0] address_cache,  //Native CPU interface address signal
        input [WDATA_W-1:0]             wdata_cache, //Native CPU interface data write signal
        input [DATA_W/8-1:0]            wstrb_cache,  //Native CPU interface write strobe signal
        output [DATA_W-1:0]             rdata_cache, //Native CPU interface read data signal
        output                          ready_cache,  //Native CPU interface ready signal
