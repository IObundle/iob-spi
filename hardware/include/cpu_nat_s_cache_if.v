	       //CPU native interface
               `INPUT(valid_cache,   1),  //Native CPU interface valid signal
	       `INPUT(address_cache, ADDR_W),  //Native CPU interface address signal
               `INPUT(wdata_cache,   WDATA_W), //Native CPU interface data write signal
	       `INPUT(wstrb_cache,   DATA_W/8),  //Native CPU interface write strobe signal
	       `OUTPUT(rdata_cache,  DATA_W), //Native CPU interface read data signal
	       `OUTPUT(ready_cache,  1),  //Native CPU interface ready signal
