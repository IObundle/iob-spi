include $(SPI_DIR)/rtl/hardware.mk

DEFINE+=$(defmacro)VCD

VSRC+=$(SPI_DIR)/rtl/testbench/spi_fl_tb.v #only flash
