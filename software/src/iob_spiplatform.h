#pragma once

#include "iob_spi_master_conf.h"
#include "iob_spi_master_swreg.h"

// Functions

void spiflash_reset();
void spiflash_init(int base_address);

// Setters
void spiflash_setDATAIN(unsigned int datain);
void spiflash_setADDRESS(unsigned int address);
void spiflash_setCOMMAND(unsigned int command);
void spiflash_setCOMMTYPE(unsigned int commtype);
void spiflash_setVALIDIN(unsigned int validin);

// Getter
unsigned int spiflash_getDATAOUT();
unsigned int spiflash_getVALIDOUT();
unsigned int spiflash_getREADY();

// General command execution trigger function
void spiflash_executecommand(int typecode, unsigned int datain,
                             unsigned int address, unsigned int command,
                             unsigned *dataout);
