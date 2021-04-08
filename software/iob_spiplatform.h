#pragma once

//Functions

void spifl_reset();
void spifl_init(int base_address);

void spifl_setDATAIN(unsigned int datain);
void spifl_setADDRESS(unsigned int address);
void spifl_setCOMMAND(unsigned int command);
void spifl_setCOMMTYPE(unsigned int commtype);
void spifl_setVALIDIN(unsigned int validin);

unsigned int spifl_getDATAOUT();
unsigned int spifl_getVALIDOUT();

void spifl_executecommand(int typecode, unsigned int datain, unsigned int address, unsigned int command, unsigned *dataout);
void spifl_waitvalidout();
