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
VHDR+=$(SPI_HW_INC_DIR)/SPIsw_reg_gen.v

#sources
ifeq ($(FPGA_FAMILY),CYCLONEV_GT)
	NETLSRC+=$(SPI_HW_DIR)/fpga/$(FPGA_COMP)/$(FPGA_FAMILY)/iob_spi_master_fl_0.qxp
else
	NETLSRC+=$(SPI_HW_DIR)/fpga/$(FPGA_COMP)/$(FPGA_FAMILY)/iob_spi_master_fl.edif
endif

SPI_SRC_DIR:=$(SPI_DIR)/hardware/src
ifeq ($(USE_NETLIST),0)
	VSRC+=$(wildcard $(SPI_HW_DIR)/src/*.v)#Adapted
endif

$(SPI_HW_INC_DIR)/SPIsw_reg_gen.v: $(SPI_HW_INC_DIR)/SPIsw_reg.v
	$(LIB_DIR)/software/mkregs.py $< HW
	mv SPIsw_reg_gen.v $(SPI_HW_INC_DIR)
	mv SPIsw_reg.vh $(SPI_HW_INC_DIR)

spi_clean_hw:
	@rm -rf $(SPI_HW_INC_DIR)/SPIsw_reg_gen.v $(SPI_HW_INC_DIR)/SPIsw_reg.vh #tmp $(SPI_HW_DIR)/fpga/vivado/XCKU $(SPI_HW_DIR)/fpga/quartus/CYCLONEV-GT

.PHONY: spi_clean_hw
