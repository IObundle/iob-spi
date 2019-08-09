#include "spi.h"

int spi_slave_cycle(int base)
{
  // wait for reception to end (until ready = 1)
  while (!spi_ready(base));

  //read the received word
  int word = spi_read(base);
  //uart_printf("0x%x\n", srw);

  //return received word
  return word;
}
