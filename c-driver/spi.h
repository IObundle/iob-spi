#ifndef SPI_H
#define SPI_H

#include "iob_memrw.h"
#include "uart.h"

#define SPI_READY 1
#define SPI_TXDATA 2
#define SPI_RXDATA 3
#define SPI_START 4
#define SPI_VERSION 5
#define SPI_SOFTRST 6
#define SPI_DUMMY 7

//slave
int spi_ready(int base);
int spi_slave_read(int base);
void spi_slave_write(int base, int data);

//master 
void spi_master_send(int base, int word);
int spi_master_rcv(int base);

//common
void spi_init(int base);

#endif
