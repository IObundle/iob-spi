#include "iob_memrw.h"
#include "spi.h"
#include "uart.h"

void spi_master_send(int base, int mcw)
{
  // wait for ready
  while (!IOB_MEMGET(base, SPI_READY));

  // write the word to send
  IOB_MEMSET(base, SPI_TXDATA, mcw);

  //uart_printf("0x%x\n", mcw);
}

int spi_master_rcv(int base)
{
  // wait for ready
  while (!IOB_MEMGET(base, SPI_READY));

  // send null word
  IOB_MEMSET(base, SPI_TXDATA, 0x0);

  // wait for ready
  while (!IOB_MEMGET(base, SPI_READY));

  //read and returned the received word
  int srw = IOB_MEMGET(base, SPI_RXDATA);
  //uart_printf("0x%x\n", srw);

  return srw;
}
