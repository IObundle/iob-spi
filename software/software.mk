include $(SPI_DIR)/core.mk

#path
SPI_SW_DIR:=$(SPI_DIR)/software

#include
INCLUDE+=-I$(SPI_SW_DIR)

#headers
HDR+=$(SPI_SW_DIR)/*.h $(SPI_SW_DIR)/SPIsw_reg.h

#sources
#SRC+=$(SPI_SW_DIR)/*.c

$(SPI_SW_DIR)/SPIsw_reg.h: $(SPI_INC_DIR)/SPIsw_reg.v
	$(LIB_DIR)/software/mkregs.py $< SW
	mv SPIsw_reg.h $@
