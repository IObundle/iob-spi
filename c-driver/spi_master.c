#include "iob_memrw.h"
#include "spi.h"

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
