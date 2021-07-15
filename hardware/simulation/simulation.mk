include $(SPI_DIR)/hardware/hardware.mk

DEFINE+=$(defmacro)VCD

VSRC+=$(SPI_DIR)/hardware/testbench/spi_fl_tb.v #only flash
VSRC+=$(SPI_DIR)/hardware/testbench/flashmodel/*.v
INCLUDE+=$(incdir) $(SPI_DIR)/hardware/testbench/flashmodel/

