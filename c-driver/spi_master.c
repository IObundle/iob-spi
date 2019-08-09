#include "spi.h"

int spi_master_cycle(int base, int word)
{
  // send word
  if(!spi_ready(base))
    uart_printf("ERROR: spi should be ready\n");
  spi_write(base, word);

  // wait for transmission to start (until ready = 0)
  while (spi_ready(base));

  // wait for trasmission to end (until ready = 1)
  while (!spi_ready(base));
  usleep(100);
  //read the received word
  int srw = spi_read(base);
  //uart_printf("0x%x\n", srw);

  //return it
  return srw;
}
