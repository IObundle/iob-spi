#include "iob-spiplatform.h"
#include "iob-spidefs.h"
#include <stddef.h>
#include <stdint.h>

// SET
void spiflash_reset() {
  IOB_SPI_MASTER_SET_FL_RESET(1); // soft reset
  IOB_SPI_MASTER_SET_FL_RESET(0);
}

void spiflash_setDATAIN(unsigned int datain) {
  IOB_SPI_MASTER_SET_FL_DATAIN(datain);
}

void spiflash_setADDRESS(unsigned int address) {
  IOB_SPI_MASTER_SET_FL_ADDRESS(address);
}

void spiflash_setCOMMAND(unsigned int command) {
  IOB_SPI_MASTER_SET_FL_COMMAND(command);
}

void spiflash_setCOMMTYPE(unsigned int commtype) {
  IOB_SPI_MASTER_SET_FL_COMMANDTP(commtype);
}

void spiflash_setVALIDIN(unsigned int validin) {
  IOB_SPI_MASTER_SET_FL_VALIDFLG(validin);
}

// GET
unsigned int spiflash_getDATAOUT() {
  unsigned int dataout;
  dataout = (unsigned int)IOB_SPI_MASTER_GET_FL_DATAOUT();
  return dataout;
}

inline unsigned spiflash_getREADY() {
  return (unsigned int)IOB_SPI_MASTER_GET_FL_READY();
}

// Higher functions
void spiflash_init(int base_address) {
  IOB_SPI_MASTER_INIT_BASEADDR(base_address);
}

void spiflash_executecommand(int typecode, unsigned int datain,
                             unsigned int address, unsigned int command,
                             unsigned *dataout) {
  spiflash_setCOMMAND(command);
  spiflash_setCOMMTYPE(typecode);
  while ((!spiflash_getREADY()))
    ;

  switch (typecode) {
  case COMM:
    spiflash_setVALIDIN(1);
    spiflash_setVALIDIN(0);
    break;
  case COMMANS:
    spiflash_setVALIDIN(1);
    spiflash_setVALIDIN(0);
    while (!spiflash_getREADY())
      ;
    *dataout = spiflash_getDATAOUT();
    break;
  case COMMADDR_ANS:
    spiflash_setADDRESS(address);
    spiflash_setVALIDIN(1);
    spiflash_setVALIDIN(0);
    while (!spiflash_getREADY())
      ;
    *dataout = spiflash_getDATAOUT();
    break;
  case COMM_DTIN:
    spiflash_setDATAIN(datain);
    spiflash_setVALIDIN(1);
    spiflash_setVALIDIN(0);
    break;
  case COMMADDR_DTIN:
    spiflash_setADDRESS(address);
    spiflash_setDATAIN(datain);
    spiflash_setVALIDIN(1);
    spiflash_setVALIDIN(0);
    break;
  case COMMADDR:
    spiflash_setADDRESS(address);
    spiflash_setVALIDIN(1);
    spiflash_setVALIDIN(0);
    break;
  case XIP_ADDRANS:
    spiflash_setADDRESS(address);
    spiflash_setVALIDIN(1);
    spiflash_setVALIDIN(0);
    while (!spiflash_getREADY())
      ;
    *dataout = spiflash_getDATAOUT();
    break;
  case RECOVER_SEQ:
    spiflash_setDATAIN(datain);
    spiflash_setVALIDIN(1);
    spiflash_setVALIDIN(0);
    break;
  default:
    spiflash_setVALIDIN(1);
    spiflash_setVALIDIN(0);
  }
}
