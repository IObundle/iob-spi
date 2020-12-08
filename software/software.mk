include $(SPI_DIR)/core.mk

#path
SPI_SW_DIR:=$(SPI_DIR)/software

#include
INCLUDE+=-I$(SPI_SW_DIR)

#headers
HDR+=$(SPI_SW_DIR)/*.h $(SPI_SW_DIR)/$(CORE_NAME)sw_reg.h

$(SPI_SW_DIR)/$(CORE_NAME)sw_reg.h: $(SPI_HW_INC_DIR)/$(CORE_NAME)sw_reg.v
	$(LIB_DIR)/software/mkregs.py $< SW
	mv $(CORE_NAME)sw_reg.h $@
