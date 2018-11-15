VC = iverilog
VFLAGS = -W all -I.  -g2005-sv

spi: spi_master.v spi_slave.v spi_tb.v spi_defines.vh
	$(VC) $(VFLAGS) spi_master.v spi_slave.v spi_tb.v	
	./a.out

spi_master: spi_master.v 
	$(VC) $(VFLAGS) spi_master.v

spi_slave: spi_slave.v 
	$(VC) $(VFLAGS) spi_slave.v

clean: 
	@rm -f a.out *~ *.vcd

.PHONY: clean spi_master spi_slave spi
