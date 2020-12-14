FPGA_OBJ?=$(FPGA_FAMILY)/spi.edif
CONSTRAINTS:=$(wildcard *.xdc)

include ../fpga.mk
run: $(FPGA_OBJ)

clean: spi_clean_hw
	rm -rf $(FPGA_FAMILY) *.v *.vh

.PHONY: run clean
