#include "iob_memrw.h"
#include "uart.h"
#include "spi.h"
#include "iob_control.h"

void spi_slave_init(unsigned int base)
{
  int dummy = 0;

  //soft reset the core
  IOB_MEMSET(base, SPI_SOFTRESET, 0x1);

  // initialize tx register
  IOB_MEMSET(base, SPI_TXDATA, 0x0);

  //test write/read dummy register
  IOB_MEMSET(base, SPI_DUMMY, 0xDEADBEEF);
  dummy = IOB_MEMGET(base, SPI_DUMMY);
  if (dummy != 0xDEADBEEF)
    uart_printf("SPI SLAVE ERROR: write/read dummy register faild 0x%x/0xDEABEFF", dummy);

}

int spi_slave_ready(unsigned int base)
{
    return IOB_MEMGET(base, SPI_READY);
}

int spi_slave_rx(unsigned int base)
{
    return IOB_MEMGET(base, SPI_RXDATA);
}

void spi_slave_tx(unsigned int base, int data)
{
  IOB_MEMSET(base, SPI_TXDATA, data);
}
