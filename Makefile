all: spi_tb.o spi_tb.vpi spi_tb.vvp
	vvp -M. -mspi_tb spi_tb.vvp

spi_tb.o spi_tb.vpi: spi_tb.c
	iverilog-vpi spi_tb.c

spi_tb.vvp: spi_tb.v
	iverilog -ospi_tb.vvp spi_tb.v spi_slave.v spi_fe.v spi_protocol.v register_bank.v 

clean: 
	rm spi_tb.vvp spi_tb.vpi spi_tb.o *~ spi_tb.vcd

.PHONY: all clean
