include $(SPI_DIR)/hardware/hardware.mk

DEFINE+=$(defmacro)VCD

VSRC+=$(SPI_DIR)/hardware/testbench/N25Qxxx.v
VSRC+=$(SPI_DIR)/hardware/testbench/spi_fl_tb.v #only flash
