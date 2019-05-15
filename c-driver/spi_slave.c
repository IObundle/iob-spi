#include "spi.h"

void spi_slave_init(int base)
{
  //soft reset the core
  IOB_MEMSET(base, SPI_SOFTRST, 0x1);

  // initialize tx register
  IOB_MEMSET(base, SPI_TXDATA, 0x0);

  //test write/read dummy register
  IOB_MEMSET(base, SPI_DUMMY, 0xDEADBEEF);

  //read dummy reg
  int dummy = IOB_MEMGET(base, SPI_DUMMY);

  //check dummy reg
  if (dummy != 0xDEADBEEF)
    uart_printf("SPI SLAVE ERROR: write/read dummy register faild 0x%x/0xDEABEFF", dummy);
}

int spi_slave_ready(int base)
{
    return IOB_MEMGET(base, SPI_READY);
}

int spi_slave_read(int base)
{
  return IOB_MEMGET(base, SPI_RXDATA);
}

int spi_slave_rx(int base)
{
  return IOB_MEMGET(base, SPI_RXDATA);
}

void spi_slave_tx(int base, int data)
{
  IOB_MEMSET(base, SPI_TXDATA, data);
}
