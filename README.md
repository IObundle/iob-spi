# IOB-SPI #
IOb-SPI hosts a SPI flash memory controller core. This core is used on a SoC to act as an SPI master and communicate with the flash memory.

## Setup
`nix-shell --run "make setup"`

## Simulate
`nix-shell --run "make -C ../iob_spi_* sim-test"`

## Clean
`nix-shell --run "make clean"`

## How do I use the core in software  
Refer the "[test_firmware.c](./software/src/test_firmware.c)" file for example driver usage.
