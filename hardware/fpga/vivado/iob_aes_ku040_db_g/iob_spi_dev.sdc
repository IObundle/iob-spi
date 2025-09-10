# ----------------------------------------------------------------------------
# IOb_spi Example Constraint File
#
# This file contains the SPI core constraints for the AES-KU040-DB-G board.
# ----------------------------------------------------------------------------

#
# User Code/Data QSPI Interface
#

# CS
set_property PACKAGE_PIN D19 [get_ports spi_SS_o]
set_property IOSTANDARD LVCMOS18 [get_ports spi_SS_o]
# CLK
set_property PACKAGE_PIN F10 [get_ports spi_SCLK_o]
set_property IOSTANDARD LVCMOS18 [get_ports spi_SCLK_o]
# DQ0
set_property PACKAGE_PIN G11 [get_ports spi_MOSI_io]
set_property IOSTANDARD LVCMOS18 [get_ports spi_MOSI_io]
# DQ1
set_property PACKAGE_PIN H11 [get_ports spi_MISO_io]
set_property IOSTANDARD LVCMOS18 [get_ports spi_MISO_io]
# DQ2
set_property PACKAGE_PIN J11 [get_ports spi_WP_N_io]
set_property IOSTANDARD LVCMOS18 [get_ports spi_WP_N_io]
# DQ3
set_property PACKAGE_PIN H12 [get_ports spi_HOLD_N_io]
set_property IOSTANDARD LVCMOS18 [get_ports spi_HOLD_N_io]

set_property IOB TRUE [get_ports spi_SS_o]
set_property IOB TRUE [get_ports spi_SCLK_o]
set_property IOB TRUE [get_cells */SPI0/fl_spi0/dq_out_r_reg[0]]
set_property IOB TRUE [get_cells */SPI0/fl_spi0/dq_out_r_reg[1]]
set_property IOB TRUE [get_cells */SPI0/fl_spi0/dq_out_r_reg[2]]
set_property IOB TRUE [get_cells */SPI0/fl_spi0/dq_out_r_reg[3]]
