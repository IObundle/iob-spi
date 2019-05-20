#include "spi.h"

void spi_init(int base)
{
  //soft reset the core
  IOB_MEMSET(base, SPI_SOFTRST, 1);

  // initialize tx register
  IOB_MEMSET(base, SPI_TXDATA, 0x0);

   //check dummy reg
  IOB_MEMSET(base, SPI_DUMMY, 0xDEADBEEF);
  int dummy = IOB_MEMGET(base, SPI_DUMMY);
  if (dummy != 0xDEADBEEF)
    uart_printf("SPI ERROR: dummy register write/read failed %x/DEADBEEF)\n", dummy);
}

