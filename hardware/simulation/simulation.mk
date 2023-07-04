include $(SPI_DIR)/hardware/hardware.mk

DEFINE+=$(defmacro)VCD

VSRC+=$(SPI_DIR)/hardware/testbench/iob_spi_tb.v
#VSRC+=$(SPI_DIR)/hardware/testbench/flashmodel/N25Qxxx.v
#INCLUDE+=$(incdir) $(SPI_DIR)/hardware/testbench/flashmodel/include

