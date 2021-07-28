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

#flash mem
#VSRC+=$(wildcard $(SPI_HW_INC_DIR)/*.hex)
#VSRC+=$(wildcard $(SPI_HW_INC_DIR)/*.vmf)

#sources
ifeq ($(FPGA_FAMILY),CYCLONEV_GT)
	NETLSRC+=$(SPI_FPGA_DIR)/$(FPGA_COMP)/$(FPGA_FAMILY)/iob_spi_master_fl_0.qxp
else
	NETLSRC+=$(SPI_FPGA_DIR)/$(FPGA_COMP)/$(FPGA_FAMILY)/iob_spi_master_fl.edif
endif

ifeq ($(USE_NETLIST),0)
	VSRC+=$(wildcard $(SPI_SRC_DIR)/*.v)#Adapted
endif

$(SPI_HW_INC_DIR)/SPIsw_reg_gen.v: $(SPI_HW_INC_DIR)/SPIsw_reg.v
	$(LIB_DIR)/software/mkregs.py $< HW
	mv SPIsw_reg_gen.v $(SPI_HW_INC_DIR)
	mv SPIsw_reg.vh $(SPI_HW_INC_DIR)

spi_clean_hw:
	@rm -rf $(SPI_HW_INC_DIR)/SPIsw_reg_gen.v $(SPI_HW_INC_DIR)/SPIsw_reg.vh tmp $(SPI_FPGA_DIR)vivado/XCKU $(SPI_FPGA_DIR)/quartus/CYCLONEV-GT

.PHONY: spi_clean_hw
