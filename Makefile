#
# TOP MAKEFILE
#

#
# SIMULATE
#

SPI_DIR:=.
include core.mk

sim:
ifeq ($(SIM_SERVER), localhost)
	make -C $(SIM_DIR) run SIMULATOR=$(SIMULATOR)
#else
#	ssh $(SIM_USER)@$(SIM_SERVER) "if [ ! -d $(USER)/$(REMOTE_ROOT_DIR) ]; then mkdir -p $(USER)/$(REMOTE_ROOT_DIR); fi"
#	make -C $(SIM_DIR) clean
#	rsync -avz --delete --exclude .git $(SPI_DIR) $(SIM_USER)@$(SIM_SERVER):$(USER)/$(REMOTE_ROOT_DIR)
#	ssh $(SIM_USER)@$(SIM_SERVER) 'cd $(USER)/$(REMOTE_ROOT_DIR); make -C $(SIM_DIR) run SIMULATOR=$(SIMULATOR) SIM_SERVER=localhost'
endif

sim-waves:
	gtkwave $(SIM_DIR)/spi_fl_tb.vcd &

sim-clean:
ifeq ($(SIM_SERVER), localhost)
	make -C $(SIM_DIR) clean
#else 
#	rsync -avz --delete --exclude .git $(SPI_DIR) $(SIM_USER)@$(SIM_SERVER):$(USER)/$(REMOTE_ROOT_DIR)
#	ssh $(SIM_USER)@$(SIM_SERVER) 'cd $(USER)/$(REMOTE_ROOT_DIR); make clean SIM_SERVER=localhost FPGA_SERVER=localhost'
endif

#
# DOCUMENT
#

doc:
	make -C document/$(DOC_TYPE) $(DOC_TYPE).pdf

doc-clean:
	make -C document/$(DOC_TYPE) clean

doc-pdfclean:
	make -C document/$(DOC_TYPE) pdfclean

clean: sim-clean doc-clean

.PHONY: sim sim-waves doc-clean clean
