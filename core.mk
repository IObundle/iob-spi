#
#	CORE DEFINITIONS
#

CORE_NAME=SPI
IS_CORE:=1
USE_NETLIST ?=0

#PATHS
SPI_HW_DIR:=$(SPI_DIR)/rtl
SPI_HW_INC_DIR:=$(SPI_HW_DIR)/include
SPI_DOC_DIR:=$(SPI_DIR)/document
SPI_SUBMODULES_DIR:=$(SPI_DIR)/submodules
INTERCON_DIR:=$(SPI_DIR)/submodules/INTERCON
LIB_DIR:=$(SPI_DIR)/submodules/LIB
TEX_DIR:=$(SPI_DIR)/submodules/TEX
#REMOTE_ROOT_DIR ?= sandbox/iob-soc/submodules/SPI should be SPI for submodule name

#
#SIMULATION
#
SIMULATOR ?=icarus
SIM_SERVER ?=localhost
SIM_USER ?=$(USER)

#SIMULATOR ?=ncsim
#SIM_SERVER ?=micro7.lx.it.pt
#SIM_USER ?=user19

SIM_DIR ?=simulation/$(SIMULATOR)#
