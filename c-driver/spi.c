#include "spi.h"

void spi_init(int base)
{
  //soft reset the core
  spi_reset(base);

  // initialize tx register
  spi_write(base, 0);

  //try write and read  dummy reg
  IOB_MEMSET(base, SPI_DUMMY, 0xDEADBEEF);

  int dummy = IOB_MEMGET(base, SPI_DUMMY);
  if (dummy != 0xDEADBEEF)
    uart_printf("SPI ERROR: dummy register write/read failed %x/DEADBEEF)\n", dummy);
}

