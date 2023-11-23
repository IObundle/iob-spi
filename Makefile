CORE := iob_spi

DISABLE_LINT:=1

all: test

LIB_DIR=submodules/IOB-SOC/submodules/LIB
PROJECT_ROOT=.

include submodules/IOB-SOC/submodules/LIB/setup.mk

test: clean 
	nix-shell --run "make build-setup && make -C ../iob_spi_* sim-run"
