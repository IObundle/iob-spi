#ifndef SPI_H
#define SPI_H

#define SPI_READY 1
#define SPI_TXDATA 2
#define SPI_RXDATA 3
#define SPI_START 4
#define SPI_VERSION 5
#define SPI_SOFTRST 6
#define SPI_DUMMY 7

//slave
#define spi_ready(base) IOB_MEMGET(base, SPI_READY)
#define spi_slave_read(base) IOB_MEMGET(base, SPI_RXDATA)
#define spi_slave_write(base, data) IOB_MEMSET(base, SPI_TXDATA, data)

//master 
void spi_master_send(int base, int word);
int spi_master_rcv(int base);

//common
void spi_init(int base);
#define spi_reset(base) IOB_MEMSET(base, SPI_SOFTRST, 1)

#endif
