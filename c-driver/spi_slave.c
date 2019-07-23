#include "iob_memrw.h"
#include "spi.h"

int spi_ready(int base)
{
    return IOB_MEMGET(base, SPI_READY);
}

int spi_slave_read(int base)
{
  return IOB_MEMGET(base, SPI_RXDATA);
}

void spi_slave_write(int base, int data)
{
  IOB_MEMSET(base, SPI_TXDATA, data);
}
