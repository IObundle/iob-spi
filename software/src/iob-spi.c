#include "iob-spi.h"
#include "iob-spidefs.h"
#include "iob-spiplatform.h"
#include "stdint.h"
#include <stddef.h>

static unsigned int base;
unsigned xipframestruct = 0;
unsigned commtypeReg = 0;

// Xip functions
int spiflash_XipEnable() {
  // write to bit 3 of volatile configuration
  // register to enable xip
  unsigned int bits = 8;
  unsigned int volative_config = 0x0;

  spiflash_readVolConfigReg(&volative_config);

  // set to bit volatile configuration XIP bit to 0
  volative_config &= ~(1 << VOLCFG_XIP);

  spiflash_executecommand(commtypeReg | COMM_DTIN, volative_config, 0,
                          (bits << CMD_NDATA_BITS) | WRITE_VOLCFGREG, NULL);
  return 1;
}

int spiflash_terminateXipSequence() {
  unsigned bits = 0;
  unsigned frame = (0x3 << FSTRUCT_CMD) | (0x3 << FSTRUCT_ADDR) |
                   (0x3 << FSTRUCT_TX) | (0x3 << FSTRUCT_RX) |
                   (DUALMODE << FSTRUCT_ALT);
  uint8_t currentmode = commtypeReg & (0x3 << CTP_SPIMODE);

  if (currentmode == 0 || currentmode == QUADMODE)
    bits = 7;
  else if (currentmode == DUALMODE)
    bits = 13;
  else
    bits = 25;

  spiflash_executecommand(
      commtypeReg | RECOVER_SEQ, 0, 0,
      (frame << CMD_FRAME_STRUCT | bits << CMD_NDATA_BITS | 0x00), NULL);
  return 0;
}

void spiflash_RecoverSequence() {
  unsigned bits = 7;
  unsigned frame = 0x00 | (DUALMODE << FSTRUCT_ADDR) | (0x3 << FSTRUCT_TX) |
                   (0x3 << FSTRUCT_RX) | (DUALMODE << FSTRUCT_ALT);
  // Power Loss Recover Sequence
  // 1st part
  spiflash_executecommand(
      RECOVER_SEQ, 0, 0,
      (frame << CMD_FRAME_STRUCT | bits << CMD_NDATA_BITS | 0x00), NULL);
  bits = 9;
  spiflash_executecommand(
      RECOVER_SEQ, 0, 0,
      (frame << CMD_FRAME_STRUCT | bits << CMD_NDATA_BITS | 0x00), NULL);
  bits = 13;
  spiflash_executecommand(
      RECOVER_SEQ, 0, 0,
      (frame << CMD_FRAME_STRUCT | bits << CMD_NDATA_BITS | 0x00), NULL);
  bits = 17;
  spiflash_executecommand(
      RECOVER_SEQ, 0, 0,
      (frame << CMD_FRAME_STRUCT | bits << CMD_NDATA_BITS | 0x00), NULL);
  bits = 25;
  spiflash_executecommand(
      RECOVER_SEQ, 0, 0,
      (frame << CMD_FRAME_STRUCT | bits << CMD_NDATA_BITS | 0x00), NULL);
  bits = 33;
  spiflash_executecommand(
      RECOVER_SEQ, 0, 0,
      (frame << CMD_FRAME_STRUCT | bits << CMD_NDATA_BITS | 0x00), NULL);

  // 2nd part
  bits = 8;
  spiflash_executecommand(
      commtypeReg | RECOVER_SEQ, 0, 0,
      (frame << CMD_FRAME_STRUCT | bits << CMD_NDATA_BITS | 0x00), NULL);
}

void enterSPImode(int spimode) {
  // Read Enhanced Volatile Register state
  unsigned enhancedReg = 0;
  unsigned bytes = 1;
  unsigned command_aux = ((bytes * 8) << CMD_NDATA_BITS) | READENHANCEDREG;
  spiflash_executecommand(commtypeReg | COMMANS, 0, 0, command_aux,
                          &enhancedReg);
  // Enhanced volatile Reg state in least significant byte

  // New mode
  unsigned int newRegVal = 0;
  unsigned int newbits = (spimode == QUADMODE)   ? 0x80
                         : (spimode == DUALMODE) ? 0x40
                                                 : 0xC0;
  newRegVal = (enhancedReg & ~(0xC0)) | newbits;

  // execute Write Enable
  spiflash_executecommand(commtypeReg | COMM, 0, 0, WRITE_ENABLE, NULL);

  // execute Write to enhanced register
  command_aux = ((bytes * 8) << CMD_NDATA_BITS) | WRITEENHANCEDREG;
  spiflash_executecommand(commtypeReg | COMM_DTIN, newRegVal, 0, command_aux,
                          NULL);
  // Verify if successfull
  // update config
  commtypeReg &= ~(0x3 << CTP_SPIMODE); // Clear
  commtypeReg |= (spimode == QUADMODE)   ? (0x2 << CTP_SPIMODE)
                 : (spimode == DUALMODE) ? (0x1 << CTP_SPIMODE)
                                         : 0x00; // Set bits
}

// Reset commands
void spiflash_resetmem() {
  // execute RESET ENABLE
  spiflash_executecommand(commtypeReg | COMM, 0, 0, RESET_ENABLE, NULL);
  // execute RESET MEM
  spiflash_executecommand(commtypeReg | COMM, 0, 0, RESET_MEM, NULL);
}

// Program/Write Memory commands
int spiflash_memProgram(char *mem, int memsize, unsigned int address) {
  int pages_programmed = 0;
  unsigned read_word = 0;
  // Command Config
  unsigned frame_struct =
      0x00 | (QUADMODE << FSTRUCT_ADDR) | (QUADMODE << FSTRUCT_TX);
  unsigned numbytes = 4; // max 4
  unsigned command = (frame_struct << CMD_FRAME_STRUCT) |
                     ((numbytes * 8) << CMD_NDATA_BITS) | PROGRAMFAST_QUADINEXT;

  unsigned int strtoProgram = 0; // must be at least 32 bits

  int memblocks = memsize / numbytes;
  int remainder_memblocks = memsize % numbytes;

  // Main programming cycle
  int i = 0, j = 0, k = 0;
  unsigned int address_aux = address, statusReg = 0;
  int numwrites = 0;
  int numbytes_aux = numbytes;
  for (i = 0; i < memsize; i = i + numbytes_aux, numwrites++) {
    if (numwrites == memblocks && remainder_memblocks != 0) {
      numbytes_aux = remainder_memblocks;
      command = 0;
      command = (frame_struct << CMD_FRAME_STRUCT) |
                ((numbytes_aux * 8) << CMD_NDATA_BITS) | PROGRAMFAST_QUADINEXT;
    } else
      numbytes_aux = numbytes;

    // concat bytes into strtoProgram
    for (j = 0, strtoProgram = 0; j < numbytes_aux; j++) {
      strtoProgram |= ((unsigned int)mem[i + j] & 0x0ff) << (j * 8);
    }

    statusReg = 0;
    // execute WRITE ENABLE
    spiflash_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
    spiflash_executecommand(COMMADDR_DTIN, strtoProgram, address_aux, command,
                            NULL);
    // check if str programming completed

    spiflash_readStatusReg(&statusReg);
    if (statusReg != 0) {
      do {
        spiflash_readStatusReg(&statusReg);
      } while (statusReg != 0);
    }

    address_aux += numbytes_aux;
  }
  return address_aux;
}

void spiflash_programfastQuadInputExt(unsigned int word, unsigned address) {
  // execute WRITE ENABLE
  spiflash_executecommand(commtypeReg | COMM, 0, 0, WRITE_ENABLE, NULL);
  // execute PAGE PROGRAM
  unsigned frame_struct =
      0x00 | (QUADMODE << FSTRUCT_ADDR) | (QUADMODE << FSTRUCT_TX);
  unsigned numbytes = 4;
  unsigned command = (frame_struct << CMD_FRAME_STRUCT) |
                     ((numbytes * 8) << CMD_NDATA_BITS) | PROGRAMFAST_QUADINEXT;
  spiflash_executecommand(commtypeReg | COMMADDR_DTIN, word, address, command,
                          NULL);
}

// Read Register Commands
unsigned int spiflash_readStatusReg(unsigned *regstatus) {
  unsigned int bytes = 1;
  spiflash_executecommand(commtypeReg | COMMANS, 0, 0,
                          ((bytes * 8) << CMD_NDATA_BITS) | READ_STATUSREG,
                          regstatus);
  return 1;
}

// Read Volatile Configuration Register
unsigned int spiflash_readVolConfigReg(unsigned *regvalue) {
  unsigned int numbits = 8;
  spiflash_executecommand(commtypeReg | COMMANS, 0, 0,
                          (numbits << CMD_NDATA_BITS) | READ_VOLCFGREG,
                          regvalue);
  return 1;
}

// Xip Read Commands
unsigned int spiflash_readMemXip(unsigned address, unsigned activateXip) {
  unsigned misobytes = 4, data = 0;
  unsigned frame_struct = xipframestruct;
  unsigned dummy_cycles = 8;
  unsigned command = 0;
  unsigned xipbit = 1;

  if (activateXip == ACTIVEXIP ||
      activateXip == TERMINATEXIP) // 2-> Activate/keep active, 3-> terminate
                                   // Xip, others ignore
    xipbit = activateXip;
  else
    xipbit = 0;

  command = (xipbit << CMD_XIPBIT_EN) | (frame_struct << CMD_FRAME_STRUCT) |
            (dummy_cycles << CMD_DUMMY_CYCLES) |
            ((misobytes * 8) << CMD_NDATA_BITS) | 0x00;

  spiflash_executecommand(commtypeReg | XIP_ADDRANS, 0, address, command,
                          &data);
  return data;
}

// Read Memory Commands

unsigned int spiflash_readfastDualOutput(unsigned address,
                                         unsigned activateXip) {
  unsigned misobytes = 4, data = 0;
  unsigned frame_struct = 0x00 | (DUALMODE << FSTRUCT_RX);
  unsigned dummy_cycles = 8;
  unsigned command = 0;
  unsigned xipbit = 1;

  if (activateXip == ACTIVEXIP ||
      activateXip == TERMINATEXIP) // 2-> Activate/keep active, 3-> terminate
                                   // Xip, others ignore
  {
    xipbit = activateXip;
    xipframestruct = (activateXip == ACTIVEXIP) ? frame_struct : 0;
  } else
    xipbit = 0;

  command = (xipbit << CMD_XIPBIT_EN) | (frame_struct << CMD_FRAME_STRUCT) |
            (dummy_cycles << CMD_DUMMY_CYCLES) |
            ((misobytes * 8) << CMD_NDATA_BITS) | READFAST_DUALOUT;

  spiflash_executecommand(commtypeReg | COMMADDR_ANS, 0, address, command,
                          &data);
  return data;
}

unsigned int spiflash_readfastQuadOutput(unsigned address,
                                         unsigned activateXip) {
  unsigned misobytes = 4, data = 0;
  unsigned frame_struct = 0x00 | (QUADMODE << FSTRUCT_RX);
  unsigned dummy_cycles = 8;
  unsigned xipbit = 1;

  if (activateXip == ACTIVEXIP ||
      activateXip == TERMINATEXIP) // 2-> Activate/keep active, 3-> terminate
                                   // Xip, others ignore
  {
    xipbit = activateXip;
    xipframestruct = (activateXip == ACTIVEXIP) ? frame_struct : 0;
  } else
    xipbit = 0;

  unsigned command = (xipbit << CMD_XIPBIT_EN) |
                     (frame_struct << CMD_FRAME_STRUCT) |
                     (dummy_cycles << CMD_DUMMY_CYCLES) |
                     ((misobytes * 8) << CMD_NDATA_BITS) | READFAST_QUADOUT;

  spiflash_executecommand(commtypeReg | COMMADDR_ANS, 0, address, command,
                          &data);
  return data;
}
unsigned int spiflash_readfastDualInOutput(unsigned address,
                                           unsigned activateXip) {
  unsigned misobytes = 4, data = 0;
  unsigned frame_struct =
      0x00 | (DUALMODE << FSTRUCT_ADDR) | (DUALMODE << FSTRUCT_RX);
  unsigned dummy_cycles = 8;
  unsigned xipbit = 1;

  // 2-> Activate/keep active, 3-> terminate Xip, others ignore
  if (activateXip == ACTIVEXIP || activateXip == TERMINATEXIP) {
    xipbit = activateXip;
    xipframestruct = (activateXip == ACTIVEXIP) ? frame_struct : 0;
  } else
    xipbit = 0;

  unsigned command = (xipbit << CMD_XIPBIT_EN) |
                     (frame_struct << CMD_FRAME_STRUCT) |
                     (dummy_cycles << CMD_DUMMY_CYCLES) |
                     ((misobytes * 8) << CMD_NDATA_BITS) | READFAST_DUALINOUT;
  spiflash_executecommand(commtypeReg | COMMADDR_ANS, 0, address, command,
                          &data);
  return data;
}

unsigned int spiflash_readfastQuadInOutput(unsigned address,
                                           unsigned activateXip) {
  unsigned misobytes = 4, data = 0;
  unsigned frame_struct =
      0x00 | (QUADMODE << FSTRUCT_ADDR) | (QUADMODE << FSTRUCT_RX);
  unsigned dummy_cycles = 10;
  unsigned xipbit = 1;

  if (activateXip == ACTIVEXIP ||
      activateXip == TERMINATEXIP) // 2-> Activate/keep active, 3-> terminate
                                   // Xip, others ignore
  {
    xipbit = activateXip;
    xipframestruct = (activateXip == ACTIVEXIP) ? frame_struct : 0;
  } else
    xipbit = 0;

  unsigned command = (xipbit << CMD_XIPBIT_EN) |
                     (frame_struct << CMD_FRAME_STRUCT) |
                     (dummy_cycles << CMD_DUMMY_CYCLES) |
                     ((misobytes * 8) << CMD_NDATA_BITS) | READFAST_QUADINOUT;

  spiflash_executecommand(commtypeReg | COMMADDR_ANS, 0, address, command,
                          &data);
  return data;
}

unsigned int spiflash_readmem(unsigned int address) {
  unsigned int data;
  // execute READ
  unsigned bytes = 4;
  spiflash_executecommand(commtypeReg | COMMADDR_ANS, 0, address,
                          ((bytes * 8) << CMD_NDATA_BITS) | READ, &data);
  return data;
}

unsigned int spiflash_readfastQuadIODTR(unsigned int address) {
  unsigned int data;
  unsigned int bytes = 4;
  unsigned int dummy_cycles = 8;
  unsigned int frame_struct =
      0x00 | (QUADMODE << FSTRUCT_ADDR) | (QUADMODE << FSTRUCT_RX);
  unsigned int command = (frame_struct << CMD_FRAME_STRUCT) |
                         (dummy_cycles << CMD_DUMMY_CYCLES) |
                         ((bytes * 8) << CMD_NDATA_BITS) | READFAST_QUADIODTR;
  unsigned int dtr_bit = 0x1 << CTP_DTR_EN;
  spiflash_executecommand(commtypeReg | COMMADDR_ANS | dtr_bit, 0, address,
                          command, &data);
  return data;
}

unsigned int spiflash_readFlashParam(unsigned address) {
  unsigned int data;
  unsigned bytes = 4;
  unsigned dummy_cycles = 8;
  spiflash_executecommand(commtypeReg | COMMADDR_ANS, 0, address,
                          (dummy_cycles << CMD_DUMMY_CYCLES) |
                              ((bytes * 8) << CMD_NDATA_BITS) | READ_FLPARAMS,
                          &data);
  return data;
}

// Erase Memory commands
void spiflash_erase_subsector(unsigned int subsector_address) {
  // write enable
  spiflash_executecommand(commtypeReg | COMM, 0, 0, WRITE_ENABLE, NULL);
  // execute ERASE
  spiflash_executecommand(commtypeReg | COMMADDR, 0, subsector_address,
                          SUB_ERASE, NULL);
}

void spiflash_erase_sector(unsigned int sector_address) {
  // Write Enable
  spiflash_executecommand(commtypeReg | COMM, 0, 0, WRITE_ENABLE, NULL);
  // execute ERASE
  spiflash_executecommand(commtypeReg | COMMADDR, 0, sector_address, SEC_ERASE,
                          NULL);
}
