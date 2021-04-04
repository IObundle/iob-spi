#include <stddef.h>
#include "iob_spi.h"
#include "iob_spiplatform.h"
#include "iob_spidefs.h"
#include "stdint.h"

static unsigned int base;
//create another static variable for upper addresses

typedef enum {SINGLE=0, DUAL, QUAD} spilaneMode;

static struct flashConfig_ 
{
    spilaneMode spimode;                            
} flashConfig;


void spifl_setMode(spilaneMode mode)
{
    flashConfig.spimode = mode;
}

spilaneMode spifl_getMode()
{
    return flashConfig.spimode;
}

//Xip functions
int spifl_XipEnable()
{
    //write to bit 3 of volatile configuration
    //register to enable xip
    unsigned int writebyte = 0xf7000000;
    unsigned int bits = 8;
    
    //execute WRITE ENABLE
	spifl_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
    
    spifl_executecommand(COMM_DTIN, writebyte, 0, (bits << 8) | WRITE_VOLCFGREG, NULL);
}

int spifl_terminateXipSequence()
{
    unsigned bits=0;
    unsigned frame= 0x0fd;
    unsigned int regvalue = 0;
    unsigned int numbits = 8;
    unsigned int bitmask = 0x08;

    if (flashConfig.spimode == QUAD)
        bits = 8;    
    else if (flashConfig.spimode == DUAL)
        bits = 13;
    else
        bits = 25;

	spifl_executecommand(RECOVER_SEQ, 0, 0, (frame <<20 | bits << 8), NULL);
    //Read volatile register to check if xip succesfully terminated
    spifl_readVolConfigReg(&regvalue);

    //Check for specific xip bit [3]
    if(bitmask & regvalue)
        return 1;
    else
        return 0;
}

//Reset commands
void spifl_resetmem()
{
	//execute RESET ENABLE
	spifl_executecommand(COMM, 0, 0, RESET_ENABLE, NULL);
	//execute RESET MEM
	spifl_executecommand(COMM, 0, 0, RESET_MEM, NULL);
}

//Program/Write Memory commands
void spifl_writemem(unsigned int word, unsigned int address)
{
	//execute WRITE ENABLE
	spifl_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
	spifl_executecommand(COMMADDR_DTIN, word, address, PAGE_PROGRAM, NULL);
}

//Read Register Commands
unsigned int spifl_readStatusReg(unsigned *regstatus)
{
     unsigned int bytes = 1;
     spifl_executecommand(COMMANS, 0, 0,((bytes*8)<<8)| READ_STATUSREG, regstatus);
     return 1;//Correct later
}

//Read Volatile Configuration Register
unsigned int spifl_readVolConfigReg(unsigned *regvalue)
{
     unsigned int numbits = 8;
     spifl_executecommand(COMMANS, 0, 0, (numbits << 8) | READ_VOLCFGREG, &regvalue);
     return 1;//Correct later
}

//Read Memory Commands
unsigned int spifl_readfastDualOutput(unsigned address)
{
    unsigned misobytes = 4, data=0;
    unsigned frame_struct = 0x00000004;//uint8 later
	unsigned dummy_cycles = 8;
    unsigned command = (frame_struct<<20)|(dummy_cycles<<16)|((misobytes*8)<<8)|READFAST_DUALOUT;
	spifl_executecommand(COMMADDR_ANS, 0, address, command, &data);
	return data;
}

unsigned int spifl_readfastQuadOutput(unsigned address)
{
    unsigned misobytes = 4, data=0;
    unsigned frame_struct = 0x00000008;//uint8 later
	unsigned dummy_cycles = 8;
    unsigned command = (frame_struct<<20)|(dummy_cycles<<16)|((misobytes*8)<<8)|READFAST_QUADOUT;
	spifl_executecommand(COMMADDR_ANS, 0, address, command, &data);
	return data;
}
unsigned int spifl_readfastDualInOutput(unsigned address)
{
    unsigned misobytes = 4, data=0;
    unsigned frame_struct = 0x00000177;//uint8 later
	unsigned dummy_cycles = 8;
    unsigned command = (frame_struct<<20)|(dummy_cycles<<16)|((misobytes*8)<<8)|READFAST_DUALINOUT;
	spifl_executecommand(COMMADDR_ANS, 0, address, command, &data);
	return data;
}

unsigned int spifl_readmem(unsigned int address)
{
	unsigned int data;	
	//execute READ
	unsigned bytes = 4;
	spifl_executecommand(COMMADDR_ANS, 0, address, ((bytes*8)<<8)|READ, &data);
	return data;
}

unsigned int spifl_readFlashParam(unsigned address)
{
	unsigned int data;
	unsigned bytes = 4;
	unsigned dummy_cycles = 8;
	spifl_executecommand(COMMADDR_ANS, 0, address, (dummy_cycles<<16)|((bytes*8)<<8)|READ_FLPARAMS, &data);
	return data;
}

//Erase Memory commands
void spifl_erasemem(unsigned int subsector_address)
{
	//execute ERASE
	spifl_executecommand(COMMADDR, 0, subsector_address,SUB_ERASE, NULL);
}
