#include "spi.h"

void spi_master_init(int base)
{
  int dummy = 0;

  //soft reset the core
  IOB_MEMSET(base, SPI_SOFTRST, 1);

   //check dummy reg
  IOB_MEMSET(base, SPI_DUMMY, 0xDEADBEEF);
  dummy = IOB_MEMGET(base, SPI_DUMMY);
  if (dummy != 0xDEADBEEF)
    uart_printf("SPI ERROR: %x/DEADBEEF)\n", dummy);
}

void spi_master_send(int base, int word)
{
  // write the word to send
  IOB_MEMSET(base, SPI_TXDATA, word);

  // wait until all bit are transmitted
  while (!IOB_MEMGET(base, SPI_READY));
}

int spi_master_rcv(int base)
{
  // send null command
  IOB_MEMSET(base, SPI_TXDATA, 0x0);

  // wait until all bits are transmitted
  while (!IOB_MEMGET(base, SPI_READY));

  //read and returned the received word
  return IOB_MEMGET(base, SPI_RXDATA);
}
