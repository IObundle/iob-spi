all : spi_master
	./spi_master

spi_master : spi_master.v spi_master_tb.v
	iverilog -o spi_master spi_fe.v spi_protocol.v spi_slave.v register_bank.v spi_master.v spi_master_tb.v

clean: 
	rm spi_master *~ *.vcd

.PHONY: clean
