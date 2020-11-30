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

void spifl_resetmem();
void spifl_writemem(unsigned int word, unsigned int address);
unsigned int spifl_readmem(unsigned int address);//extend for more than 4 bytes
void spifl_erasemem(unsigned int subsector_address);//extend for other erase type, ex bulk

void spifl_executecommand(int typecode, unsigned int datain, unsigned int address, unsigned int command, unsigned *dataout);
void spifl_waitvalidout();
//wear-leveling
//set DIV
//set num bytes in and out, aligned, padded?
