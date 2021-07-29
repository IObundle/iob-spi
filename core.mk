#
#	CORE DEFINITIONS
#

CORE_NAME=SPI
IS_CORE=1
USE_NETLIST ?=0
TOP_MODULE:=iob_spi_master_fl

#PATHS
SPI_HW_DIR:=$(SPI_DIR)/hardware
SPI_INC_DIR:=$(SPI_HW_DIR)/include
SPI_SRC_DIR:=$(SPI_HW_DIR)/src
SPI_TB_DIR:=$(SPI_HW_DIR)/testbench
SPI_FPGA_DIR:=$(SPI_HW_DIR)/fpga
SPI_SW_DIR:=$(SPI_DIR)/software
SPI_DOC_DIR:=$(SPI_DIR)/document
SPI_SUBMODULES_DIR:=$(SPI_DIR)/submodules
REMOTE_ROOT_DIR ?=sandbox/iob-soc/submodules/SPI

#SUBMODULES
SPI_SUBMODULES:=INTERCON LIB TEX
$(foreach p, $(SPI_SUBMODULES), $(eval $p_DIR ?=$(SPI_SUBMODULES_DIR)/$p))

RUN_FLASH ?=0
ifeq ($(RUN_FLASH),1)
DEFINE+=$(defmacro)RUN_FLASH
endif

#
#SIMULATION
#
SIMULATOR ?=icarus

SIM_DIR ?=hardware/simulation/$(SIMULATOR)

#
#FPGA
#
#FPGA_FAMILY ?=CYCLONEV-GT
FPGA_FAMILY ?=XCKU
FPGA_SERVER ?=pudim-flan.iobundle.com
FPGA_USER ?= $(USER)

ifeq ($(FPGA_FAMILY),XCKU)
	FPGA_COMP:=vivado
	FPGA_PART:=xcku040-fbva676-1-c
else
	FPGA_COMP:=quartus
	FPGA_PART:=5CGTFD9E5F35C7
endif
FPGA_DIR ?=$(SPI_DIR)/hardware/fpga/$(FPGA_COMP)

ifeq ($(FPGA_COMP),vivado)
		FPGA_LOG:=vivado.log
else ifeq ($(FPGA_COMP),quartus)
FPGA_LOG:=quartus.log
endif

#ASIC
ASIC_NODE ?=umc130
ASIC_SERVER ?=micro5.lx.it.pt
ASIC_COMPILE_ROOT_DIR ?=$(ROOT_DIR)/sandbox/iob-cache
ASIC_USER ?=user14
ASIC_DIR ?=hardware/asic/$(ASIC_NODE)

#
#DOCUMENT
#
#DOC_TYPE:=pb
DOC_TYPE:=ug
INTEL ?=0
XILINX ?=1

VLINE:="V$(VERSION)"
$(CORE_NAME)_version.txt:
ifeq ($(VERSION),)
	$(error "variable VERSION is not set")
endif
	echo $(VLINE) > version.txt
