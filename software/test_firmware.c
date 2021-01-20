#include "system.h"
#include "periphs.h"
#include "iob-uart.h"
#include "iob_timer.h"
#include "iob_spi.h"
#include "SPIsw_reg.h"
#include "interconnect.h"


int main()
{
	
  	unsigned int word = 0xFAFAB0CA;
	unsigned int address = 0x000100;
	unsigned int read_mem = 0xF0F0F0F0;
 	//init timer and uart
	timer_init(TIMER_BASE);
   	uart_init(UART_BASE, FREQ/BAUD);

	//init spi flash controller
	spifl_init(SPI_BASE);

	uart_printf("\nTesting SPI flash controller\n");

	uart_txwait();
	
	uart_printf("\nResetting flash memory\n");

	uart_txwait();

	//spifl_resetmem();
	uart_sleep(10);

	//Write(Program) to flash memory
	uart_printf("\nWriting word: (%x) to flash\n", word);
	spifl_writemem(word, address);
	uart_txwait();
	
	unsigned reg=0, reg1 = 0;
    spifl_readStatusReg(&reg);

    reg1 = IO_GET(SPI_BASE, FL_DATAOUT);


	//Read from flash memory
	/*uart_printf("\nReading from flash\n");
	read_mem = spifl_readmem(address);
	uart_txwait();

	if(word == read_mem){
		uart_printf("\nMemory Read (%x) got same word as Programmed(%x)\nSuccess\n", read_mem, word);
	}
	else{
		uart_printf("\nDifferent word from memory\nRead: (%x), Programmed: (%x)\n", read_mem, word);
	}

	uart_txwait();*/
	return 0;
}
