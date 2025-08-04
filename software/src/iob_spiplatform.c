#include "iob_spiplatform.h"
#include "iob_spidefs.h"
#include <stddef.h>
#include <stdint.h>

// SET
void spiflash_reset() {
  iob_spi_master_csrs_set_fl_reset(1); // soft reset
  iob_spi_master_csrs_set_fl_reset(0);
}

void spiflash_setDATAIN(unsigned int datain) {
  iob_spi_master_csrs_set_fl_datain(datain);
}

void spiflash_setADDRESS(unsigned int address) {
  iob_spi_master_csrs_set_fl_address(address);
}

void spiflash_setCOMMAND(unsigned int command) {
  iob_spi_master_csrs_set_fl_command(command);
}

void spiflash_setCOMMTYPE(unsigned int commtype) {
  iob_spi_master_csrs_set_fl_commandtp(commtype);
}

void spiflash_setVALIDIN(unsigned int validin) {
  iob_spi_master_csrs_set_fl_validflg(validin);
}

// GET
unsigned int spiflash_getDATAOUT() {
  unsigned int dataout;
  dataout = (unsigned int)iob_spi_master_csrs_get_fl_dataout();
  return dataout;
}

inline unsigned spiflash_getREADY() {
  return (unsigned int)iob_spi_master_csrs_get_fl_ready();
}

// Higher functions
void spiflash_init(int base_address) {
  iob_spi_master_csrs_init_baseaddr(base_address);
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
