#include "system.h"
#include "periphs.h"
#include "iob-uart.h"
//#include "iob_timer.h"
#include "iob_spi.h"
#include "iob_spidefs.h"


int main()
{
	
  	unsigned int word = 0xFAFAB0CA;
	unsigned int address = 0x000100;
	unsigned int read_mem = 0xF0F0F0F0;
 	//init timer and uart
	//timer_init(TIMER_BASE);
   	uart_init(UART_BASE, FREQ/BAUD);

	//init spi flash controller
	spifl_init(SPI_BASE);

	uart_printf("\nTesting SPI flash controller\n");

	uart_txwait();
	
	//uart_printf("\nResetting flash memory\n");

	//uart_txwait();

	//spifl_resetmem();
	
	//Write(Program) to flash memory
	//unsigned reg = 0xff;
	//spifl_readStatusReg(&reg);
	//uart_printf("\nStatus before write (%x)\n", reg);
	//uart_sleep(10);
	//uart_printf("\nWriting word: (%x) to flash\n", word);
	//spifl_writemem(word, address);
	//uart_txwait();
	
	//reg = 0xff;
	//unsigned reg1 = 0;
	//spifl_readStatusReg(&reg);

	//reg1 = IO_GET(SPI_BASE, FL_DATAOUT);

	//uart_printf("\nStatus (%x)\n", reg);
	//uart_printf("\nStatus1 (%x)\n", reg1);

	unsigned bytes = 4, readid = 0;
	spifl_executecommand(COMMANS, 0, 0, ((bytes*8)<<8)|READ_ID, &readid);

	uart_printf("\nREAD_ID: (%x)\n", readid);
	//Read from flash memory
	uart_printf("\nReading from flash (address: (%x))\n", address);
	read_mem = spifl_readmem(address);
	uart_txwait();

	if(word == read_mem){
		uart_printf("\nMemory Read (%x) got same word as Programmed(%x)\nSuccess\n", read_mem, word);
	}
	else{
		uart_printf("\nDifferent word from memory\nRead: (%x), Programmed: (%x)\n", read_mem, word);
	}

	uart_txwait();
	return 0;
}
