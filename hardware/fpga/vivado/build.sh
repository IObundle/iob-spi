#!/usr/bin/bash
TOP_MODULE="iob_spi_master_fl"

export XILINXPATH=/opt/Xilinx
export LM_LICENSE_FILE=$LM_LICENSE_FILE:$XILINXPATH/Xilinx.lic
source /opt/Xilinx/Vivado/settings64.sh
vivado -nojournal -log vivado.log -mode batch -source ../spi.tcl -tclargs "$TOP_MODULE" "$1" "$2" "$3" "$4"
