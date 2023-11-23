# IOB-SPI #
IOb-SPI hosts a SPI flash memory controller core. This core is used on a SoC to act as an SPI master and communicate with the flash memory.

## Test iob-spi-master
To quickly test the correct behaviour of the iob-spi-master core, simply run `make test`. This command will clean any previous existing build directory, create a new build directory and simulate the core with IVerilog. If you wish to run each step individually, here are the commands:

### Clean
`nix-shell --run "make clean"`

### Setup
`nix-shell --run "make build-setup"`

### Simulate
`nix-shell --run "make -C ../iob_spi_* sim-run"`

## How do I use the core in software  
Refer the "[test_firmware.c](./software/src/test_firmware.c)" file for example driver usage.
