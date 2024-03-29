#include "iob-uart.h"
#include "iob_spi.h"
#include "iob_spidefs.h"
#include "iob_spiplatform.h"
#include "periphs.h"
#include "printf.h"
#include "system.h"

int main() {
  unsigned int word = 0xFAFAB0CA;
  unsigned int address = 0x000100;
  unsigned int read_mem = 0xF0F0F0F0;
  uart_init(UART_BASE, FREQ / BAUD);

  // init spi flash controller
  spiflash_init(SPI_BASE);

  printf("\nTesting SPI flash controller\n");

  // printf("\nApplying Recover Sequence\n");
  // spiflash_RecoverSequence();

  /*printf("\nReading flash parameters: command 0x5a\n");
  unsigned int addressparam = 0x30, wordparam=0;
  wordparam = spiflash_readFlashParam(addressparam);

  printf("\nParameter Values (address (%x)):(%x)\n",addressparam,wordparam);
*/
  // printf("\nResetting flash memory\n");
  // spiflash_resetmem();

  // Reading Status Reg
  unsigned reg = 0x00;
  spiflash_readStatusReg(&reg);
  printf("\nStatus reg (%x)\n", reg);

  // Testing Fast Read in single, dual, quad
  unsigned bytes = 4, readid = 0;
  unsigned frame = 0x00000000;
  unsigned commFastRead = 0x0b;
  unsigned fastReadmem0 = 0, fastReadmem1 = 0, fastReadmem2 = 0;
  unsigned dummycycles = 8;
  /*
  //single
  spiflash_executecommand(COMMADDR_ANS, 0, 0,
  (frame<<20)|(dummycycles<<16)|((bytes*8)<<8)|commFastRead, &fastReadmem0);
  //dual
  frame = 0x00000177;
  dummycycles = 8;
  spiflash_executecommand(COMMADDR_ANS, 0, 0,
  (frame<<20)|(dummycycles<<16)|((bytes*8)<<8)|commFastRead, &fastReadmem1);
  //quad
  frame = 0x000002bb;
  dummycycles = 10;
  spiflash_executecommand(COMMADDR_ANS, 0, 0,
  (frame<<20)|(dummycycles<<16)|((bytes*8)<<8)|commFastRead, &fastReadmem2);

  printf("\nFastRead:\n\tSingle:(%x)\n\tDual:(%x)\n\tQuad:(%x)\n", fastReadmem0,
  fastReadmem1, fastReadmem2);
*/
  // Read ID
  bytes = 4;
  readid = 0;
  spiflash_executecommand(COMMANS, 0, 0, ((bytes * 8) << 8) | READ_ID, &readid);

  printf("\nREAD_ID: (%x)\n", readid);
  // Read from flash memory
  printf("\nReading from flash (address: (%x))\n", address);
  read_mem = spiflash_readmem(address);

  if (word == read_mem) {
    printf("\nMemory Read (%x) got same word as Programmed(%x)\nSuccess\n",
           read_mem, word);
  } else {
    printf("\nDifferent word from memory\nRead: (%x), Programmed: (%x)\n",
           read_mem, word);
  }

  address = 0x0;
  read_mem = 1;
  printf("\nTesting dual output fast read\n");
  read_mem = spiflash_readfastDualOutput(address + 1, 0);
  printf("\nRead from memory address (%x) the word: (%x)\n", address, read_mem);

  read_mem = 2;
  printf("\nTesting quad output fast read\n");
  read_mem = spiflash_readfastQuadOutput(address + 1, 0);
  printf("\nRead 2 from memory address (%x) the word: (%x)\n", address + 1,
         read_mem);

  read_mem = 3;
  printf("\nTesting dual input output fast read 0xbb\n");
  read_mem = spiflash_readfastDualInOutput(address + 1, 0);
  printf("\nRead 2 from memory address (%x) the word: (%x)\n", address + 2,
         read_mem);

  read_mem = 4;
  printf("\nTesting quad input output fast read 0xeb\n");
  read_mem = spiflash_readfastQuadInOutput(address + 1, 0);
  printf("\nRead 2 from memory address (%x) the word: (%x)\n", address + 3,
         read_mem);

  printf("\nRead Non volatile Register\n");
  unsigned nonVolatileReg = 0;
  bytes = 2;
  unsigned command_aux = 0xb5;
  spiflash_executecommand(COMMANS, 0, 0, ((bytes * 8) << 8) | command_aux,
                          &nonVolatileReg);
  printf("\nNon volatile Register (16 bits):(%x)\n", nonVolatileReg);
  // uart_txwait();

  printf("\nRead enhanced volatile Register\n");
  unsigned enhancedReg = 0;
  bytes = 1;
  command_aux = 0x65;
  frame = 0x00000000;
  spiflash_executecommand(COMMANS, 0, 0,
                          (frame << 20) | ((bytes * 8) << 8) | command_aux,
                          &enhancedReg);
  printf("\nEnhanced volatile Register (8 bits):(%x)\n", enhancedReg);

  // Write enhanced reg
  /*
  command_aux = 0x61;
  unsigned dtin = 0xdf000000;
  bytes = 1;
  frame = 0x000001df;
  printf("\nWrite enhanced reg\n");
  spiflash_executecommand(COMM_DTIN, dtin, 0,
  (frame<<20)|((bytes*8)<<8)|command_aux, NULL); printf("\nRead enhanced
  volatile Register\n");

  command_aux = 0x65;
  enhancedReg = 4;
  spiflash_executecommand(COMMANS, 0, 0, ((bytes*8)<<8)|command_aux,
  &enhancedReg); printf("\nEnhanced volatile Register after write (8
  bits):(%x)\n", enhancedReg);
  */

  // Testing memory program
  /*unsigned int program_address = 0x200;
  unsigned int program_word = 0;
  char word_bytes[4] = "aqui";
  printf("\n====================\n");
  printf("\nTesting word program\n");
  int j=0;
  for(j=0; j < 4; j++){
      program_word |= ((unsigned int)word_bytes[j] & 0x0ff)     << (j*8);
       }
  printf("Concate'd word: %x\n", program_word);
  spiflash_programfastQuadInputExt(program_word, program_address);
  unsigned int statusRegP = 0xff;
  for(j=0;j<5;j++){
      spiflash_readStatusReg(&statusRegP);
      printf("After program: status reg %x\n", statusRegP);
  }
  //printf("After quad ext program command\n");
  unsigned int readmemP =0;
  readmemP = spiflash_readfastQuadOutput(program_address,0);
  printf("Read from memory: %x\n", readmemP);
  printf("\n===================\n");
  */
  // Testing xip bit enabling and xip termination sequence
  printf("\nTesting xip enabling through volatile bit and termination by "
         "sequence\n");
  unsigned volconfigReg = 0;

  printf("\nResetting flash registers...\n");
  spiflash_resetmem();

  spiflash_readVolConfigReg(&volconfigReg);
  printf("\nVolatile Configuration Register (8 bits):(%x)\n", volconfigReg);

  spiflash_XipEnable();

  volconfigReg = 0;
  spiflash_readVolConfigReg(&volconfigReg);
  printf(
      "\nAfter xip bit write, Volatile Configuration Register (8 bits):(%x)\n",
      volconfigReg);
  // uart_txwait();

  // Confirmation bit 0
  read_mem = 1;
  printf("\nTesting quad input output fast read with xip confirmation bit 0\n");
  read_mem = spiflash_readfastQuadInOutput(address + 1, ACTIVEXIP);
  printf("\nRead from memory address (%x) the word: (%x)\n", address + 1,
         read_mem);

  int xipEnabled = 10;
  xipEnabled = spiflash_terminateXipSequence();
  printf("\nAfter xip termination sequence: %d\n", xipEnabled);
  volconfigReg = 0;
  spiflash_readVolConfigReg(&volconfigReg);
  printf("\nAfter xip termination sequence, Volatile Configuration Register (8 "
         "bits):(%x)\n",
         volconfigReg);

  /*read_mem = 1;
  printf("\nTesting dual output fast read with xip confirmation bit 0\n");
  read_mem = spiflash_readfastDualOutput(address + 1, ACTIVEXIP);
  printf("\nRead from memory address (%x) the word: (%x)\n", address+1,
  read_mem);

  printf("\nAssuming Xip active, read from memory, confirmation bit 0\n");
  read_mem = 1;
  read_mem = spiflash_readMemXip(address+1, ACTIVEXIP);
  printf("\nRead from memory address (%x) the word: (%x)\n", address+1,
  read_mem); uart_txwait();
  */
  if (volconfigReg == 0xf3 || volconfigReg != 0xfb) {

    printf("\nAssuming Xip active, read from memory, confirmation bit 1\n");
    read_mem = 1;
    read_mem = spiflash_readMemXip(address + 1, TERMINATEXIP);
    printf("\nRead from memory address (%x) the word: (%x)\n", address + 1,
           read_mem);
  }

  /*printf("\nAssuming Xip active, read from memory, confirmation bit 1\n");
  read_mem = 1;
  read_mem = spiflash_readMemXip(address+1, TERMINATEXIP);
  printf("\nRead from memory address (%x) the word: (%x)\n", address+1,
  read_mem); uart_txwait();

  volconfigReg = 0;
  spiflash_readVolConfigReg(&volconfigReg);
  printf("\nAfter xip termination with confirmation bit 1, Volatile
  Configuration Register (8 bits):(%x)\n", volconfigReg); uart_txwait();*/

  // Testing programming functions
  /*address = 104;
  printf("\nTesting PROGRAM functions\n");
  word = 0x11335577;
  printf("Fast program dual input ext\n");
  spiflash_programfastDualInputExt(word, address);

  address = 108;
  word = 0x99aabbcc;
  printf("Fast program quad input\n");
  spiflash_programfastQuadInput(word, address);

  address = 104;
  read_mem = 0;
  printf("\nAfter program, Quad input output fast read 0xeb\n");
  read_mem = spiflash_readfastQuadInOutput(address, 0);
  printf("\nRead after program from memory address (%x) the word: (%x)\n",
  address, read_mem);

  address = 108;
  read_mem = 1;
  printf("\nAfter program, Quad input output fast read 0xeb\n");
  read_mem = spiflash_readfastQuadInOutput(address, 0);
  printf("\nRead after program from memory address (%x) the word: (%x)\n",
  address, read_mem);
*/
  uart_finish();
  exit(0);
}
