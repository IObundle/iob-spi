#ifndef SPI_H
#define SPI_H

#include <unistd.h>
#include "iob_memrw.h"
#include "iob-uart.h"

#define SPI_READY 1
#define SPI_TXDATA 2
#define SPI_RXDATA 3
#define SPI_START 4
#define SPI_VERSION 5
#define SPI_SOFTRST 6
#define SPI_DUMMY 7

//master 
int spi_master_cycle(int base, int word);

//slave
int spi_slave_cycle(int base);

//common
#define spi_reset(base) IOB_MEMSET(base, SPI_SOFTRST, 1)
#define spi_ready(base) IOB_MEMGET(base, SPI_READY)
void spi_init(int base);
#define spi_read(base) IOB_MEMGET(base, SPI_RXDATA)
#define spi_write(base, word) IOB_MEMSET(base, SPI_TXDATA, word)

#endif
