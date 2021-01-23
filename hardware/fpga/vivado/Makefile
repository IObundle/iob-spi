FPGA_OBJ?=$(FPGA_FAMILY)/iob_spi_master_fl.edif
CONSTRAINTS:=$(wildcard *.xdc)

include ../fpga.mk
run: $(FPGA_OBJ)

clean: spi_clean_hw
	rm -rf $(FPGA_FAMILY) *.v *.vh

.PHONY: run clean
