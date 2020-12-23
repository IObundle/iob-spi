#exports software embedded stuff to system; SPI_DIR def    ined in system.mk
 
include $(SPI_DIR)/software/software.mk
 
#embeded sources
SRC+=$(SPI_SW_DIR)/embedded/*.c

