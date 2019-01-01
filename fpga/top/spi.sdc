####################################################################
#
#
#   Description: SPI Constraints File
#
#   Copyright (C) 2018 IObundle, Lda  All rights reserved
#
#####################################################################


# Set the current design
current_design spi_top

create_clock -name "clk" -add -period 10.0 [get_ports clk]
create_clock -name "sclk" -add -period 25.0 [get_ports sclk]

set_false_path -from [get_clocks $clk] -to [get_clocks $sclk]
set_false_path -from [get_clocks $sclk] -to [get_clocks $clk]
