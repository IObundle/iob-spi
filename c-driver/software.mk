include $(SPI_DIR)/core.mk

#path
SPI_SW_DIR:=$(SPI_DIR)/software

#include
INCLUDE+=-I$(SPI_SW_DIR)

#headers
HDR+=$(SPI_SW_DIR)/*.h $(SPI_SW_DIR)/spi_sw_reg.h

$(SPI_SW_DIR)/spi_sw_reg.h: $(SPI_HW_INC_DIR)/sw_reg.v
	$(LIB_DIR)/software/mkregs.py $< SW
	mv sw_reg.h $@
