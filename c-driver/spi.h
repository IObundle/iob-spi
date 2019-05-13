#ifndef SPI_H
#define SPI_H

#define SPI_READY 1
#define SPI_TXDATA 2
#define SPI_RXDATA 3
#define SPI_VERSION 5
#define SPI_SOFTRESET 6
#define SPI_DUMMY 7

void spi_slave_init(unsigned int);
int  spi_slave_ready(unsigned int);
int spi_slave_rx();
void spi_slave_tx(unsigned int, int);

#endif
