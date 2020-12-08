include $(SPI_DIR)/core.mk

#define

#include
INCLUDE+=$(incdir) $(SPI_HW_INC_DIR)
INCLUDE+=$(incdir) $(LIB_DIR)/hardware/include
INCLUDE+=$(incdir) $(INTERCON_DIR)/hardware/include 

#headers
VHDR+=$(wildcard $(SPI_HW_INC_DIR)/*.vh)#Adapted
VHDR+=$(wildcard $(LIB_DIR)/hardware/include/*.vh)
VHDR+=$(wildcard $(INTERCON_DIR)/hardware/include/*.vh $(INTERCON_DIR)/hardware/include/*.v)
VHDR+=$(SPI_HW_INC_DIR)/$(CORE_NAME)sw_reg_gen.v

#sources
SPI_SRC_DIR:=$(SPI_DIR)/hardware/src
VSRC+=$(wildcard $(SPI_HW_DIR)/src/*.v)#Adapted

$(SPI_HW_INC_DIR)/$(CORE_NAME)sw_reg_gen.v: $(SPI_HW_INC_DIR)/$(CORE_NAME)sw_reg.v
	$(LIB_DIR)/software/mkregs.py $< HW
	mv $(CORE_NAME)sw_reg_gen.v $(SPI_HW_INC_DIR)
	mv $(CORE_NAME)sw_reg_w.vh $(SPI_HW_INC_DIR)

clean_hw:
	@rm -rf $(SPI_HW_INC_DIR)/$(CORE_NAME)sw_reg_gen.v $(SPI_HW_INC_DIR)/$(CORE_NAME)sw_reg_w.vh #tmp $(SPI_HW_DIR)/fpga/vivado/XCKU $(SPI_HW_DIR)/fpga/quartus/CYCLONEV-GT

.PHONY: clean_hw
