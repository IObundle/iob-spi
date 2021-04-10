#include "system.h"
#include "periphs.h"
#include "iob-uart.h"
//#include "iob_timer.h"
#include "iob_spi.h"
#include "iob_spiplatform.h"
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
	
    /*uart_printf("\nResetting flash memory\n");
    unsigned frame_reset = 0x00000100;
	//execute RESET ENABLE
	spifl_executecommand(COMM, 0, 0, (frame_reset << 20)|RESET_ENABLE, NULL);
	//execute RESET MEM
	spifl_executecommand(COMM, 0, 0, (frame_reset << 20)|RESET_MEM, NULL);
*/
	uart_txwait();
	
	uart_printf("\nReading flash parameters: command 0x5a\n");
	unsigned int addressparam = 0x30, wordparam=0;
	wordparam = spifl_readFlashParam(addressparam);

	uart_printf("\nParameter Values (address (%x)):(%x)\n",addressparam,wordparam);

	//uart_printf("\nResetting flash memory\n");

	//uart_txwait();

	//spifl_resetmem();
	
	//Write(Program) to flash memory
	unsigned reg = 0x00;
	spifl_readStatusReg(&reg);
	uart_printf("\nStatus reg (%x)\n", reg);
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


    //Testing Fast Read in single, dual, quad
	unsigned bytes = 4, readid = 0;
    unsigned frame = 0x00000000;
    unsigned commFastRead = 0x0b;
    unsigned fastReadmem0 = 0, fastReadmem1 = 0, fastReadmem2 =0;
    unsigned dummycycles = 8;
    /*
    //single
	spifl_executecommand(COMMADDR_ANS, 0, 0, (frame<<20)|(dummycycles<<16)|((bytes*8)<<8)|commFastRead, &fastReadmem0);
	//dual
    frame = 0x00000177;
    dummycycles = 8;
    spifl_executecommand(COMMADDR_ANS, 0, 0, (frame<<20)|(dummycycles<<16)|((bytes*8)<<8)|commFastRead, &fastReadmem1);
	//quad
    frame = 0x000002bb;
    dummycycles = 10;
    spifl_executecommand(COMMADDR_ANS, 0, 0, (frame<<20)|(dummycycles<<16)|((bytes*8)<<8)|commFastRead, &fastReadmem2);

    uart_printf("\nFastRead:\n\tSingle:(%x)\n\tDual:(%x)\n\tQuad:(%x)\n", fastReadmem0, fastReadmem1, fastReadmem2);
*/
    //Read ID
    bytes = 4;
    readid = 0;
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
    
    read_mem = 1;
    uart_printf("\nTesting dual output fast read\n");
    read_mem = spifl_readfastDualOutput(address + 1, 0);
    uart_printf("\nRead from memory address (%x) the word: (%x)\n", address+1, read_mem);

    read_mem = 2;
    uart_printf("\nTesting quad output fast read\n");
    read_mem = spifl_readfastQuadOutput(address + 1, 0);
    uart_printf("\nRead 2 from memory address (%x) the word: (%x)\n", address+1, read_mem);
    
    read_mem = 3;
    uart_printf("\nTesting dual input output fast read 0xbb\n");
    read_mem = spifl_readfastDualInOutput(address + 1, 0);
    uart_printf("\nRead 2 from memory address (%x) the word: (%x)\n", address+1, read_mem);

    read_mem = 4;
    uart_printf("\nTesting quad input output fast read 0xeb\n");
    read_mem = spifl_readfastQuadInOutput(address + 1, 0);
    uart_printf("\nRead 2 from memory address (%x) the word: (%x)\n", address+1, read_mem);

    uart_printf("\nRead Non volatile Register\n");
    unsigned nonVolatileReg = 0;
	bytes = 2;
    unsigned command_aux = 0xb5;
	spifl_executecommand(COMMANS, 0, 0, ((bytes*8)<<8)|command_aux, &nonVolatileReg);
	uart_printf("\nNon volatile Register (16 bits):(%x)\n", nonVolatileReg);	
    uart_txwait();
    
    uart_printf("\nRead enhanced volatile Register\n");
    unsigned enhancedReg = 0;
	bytes = 1;
    command_aux = 0x65;
    frame = 0x00000000;
	spifl_executecommand(COMMANS, 0, 0, (frame<<20)|((bytes*8)<<8)|command_aux, &enhancedReg);
	uart_printf("\nEnhanced volatile Register (8 bits):(%x)\n", enhancedReg);	

    //Write enhanced reg
    /*
    command_aux = 0x61;
    unsigned dtin = 0xdf000000;
    bytes = 1;
    frame = 0x000001df;
    uart_printf("\nWrite enhanced reg\n");
	spifl_executecommand(COMM_DTIN, dtin, 0, (frame<<20)|((bytes*8)<<8)|command_aux, NULL);
    uart_printf("\nRead enhanced volatile Register\n");
    
    command_aux = 0x65;
    enhancedReg = 4;
	spifl_executecommand(COMMANS, 0, 0, ((bytes*8)<<8)|command_aux, &enhancedReg);
	uart_printf("\nEnhanced volatile Register after write (8 bits):(%x)\n", enhancedReg);	
    */
    uart_txwait();
    
    //Testing xip bit enabling and xip termination sequence
	uart_printf("\nTesting xip enabling through volatile bit and termination by sequence\n");	
    unsigned volconfigReg = 0;

    uart_printf("\nResetting flash registers...\n");
    spifl_resetmem();

    spifl_readVolConfigReg(&volconfigReg);
	uart_printf("\nVolatile Configuration Register (8 bits):(%x)\n", volconfigReg);	
    
    spifl_XipEnable();
    
    volconfigReg = 0;
    spifl_readVolConfigReg(&volconfigReg);
	uart_printf("\nAfter xip bit write, Volatile Configuration Register (8 bits):(%x)\n", volconfigReg);	
    uart_txwait();
    
    //Confirmation bit 0
    read_mem = 1;
    uart_printf("\nTesting dual output fast read with xip confirmation bit 0\n");
    read_mem = spifl_readfastDualOutput(address + 1, ACTIVEXIP);
    uart_printf("\nRead from memory address (%x) the word: (%x)\n", address+1, read_mem);
    
    int xipEnabled = 10;
    xipEnabled = spifl_terminateXipSequence();
    uart_printf("\nAfter xip termination sequence: %d\n", xipEnabled);
    volconfigReg = 0;
    spifl_readVolConfigReg(&volconfigReg);
	uart_printf("\nAfter xip termination sequence, Volatile Configuration Register (8 bits):(%x)\n", volconfigReg);	
    uart_txwait();
    
    /*read_mem = 1;
    uart_printf("\nTesting dual output fast read with xip confirmation bit 0\n");
    read_mem = spifl_readfastDualOutput(address + 1, ACTIVEXIP);
    uart_printf("\nRead from memory address (%x) the word: (%x)\n", address+1, read_mem);

    uart_printf("\nAssuming Xip active, read from memory, confirmation bit 0\n");
    read_mem = 1;
    read_mem = spifl_readMemXip(address+1, ACTIVEXIP);
    uart_printf("\nRead from memory address (%x) the word: (%x)\n", address+1, read_mem);
    uart_txwait();
    */
    if(volconfigReg == 0xf3 || volconfigReg != 0xfb){

        uart_printf("\nAssuming Xip active, read from memory, confirmation bit 1\n");
        read_mem = 1;
        read_mem = spifl_readMemXip(address+1, TERMINATEXIP);
        uart_printf("\nRead from memory address (%x) the word: (%x)\n", address+1, read_mem);
        uart_txwait();
        
        volconfigReg = 0;
        spifl_readVolConfigReg(&volconfigReg);
        uart_printf("\nAfter xip termination xip bit 1, Volatile Configuration Register (8 bits):(%x)\n", volconfigReg);	
        uart_txwait();
    }
    /*uart_printf("\nAssuming Xip active, read from memory, confirmation bit 1\n");
    read_mem = 1;
    read_mem = spifl_readMemXip(address+1, TERMINATEXIP);
    uart_printf("\nRead from memory address (%x) the word: (%x)\n", address+1, read_mem);
    uart_txwait();
    
    volconfigReg = 0;
    spifl_readVolConfigReg(&volconfigReg);
	uart_printf("\nAfter xip termination with confirmation bit 1, Volatile Configuration Register (8 bits):(%x)\n", volconfigReg);	
    uart_txwait();*/
    return 0;
}
