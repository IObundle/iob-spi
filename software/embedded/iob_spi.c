#include <stddef.h>
#include "iob_spi.h"
#include "iob_spiplatform.h"
#include "iob_spidefs.h"
#include "stdint.h"
#include "printf.h"

static unsigned int base;
//create another static variable for upper addresses

typedef enum {SINGLE=0, DUAL, QUAD} spilaneMode;

static spilaneMode spimode = SINGLE;                            
static unsigned xipframestruct = 0;
static int page_size=256;

/*static struct flashConfig_ 
{
    spilaneMode spimode = SINGLE;                            
} flashConfig;


void spifl_setMode(spilaneMode mode)
{
    flashConfig.spimode = mode;
}

spilaneMode spifl_getMode()
{
    return flashConfig.spimode;
}*/

//Xip functions
int spifl_XipEnable()
{
    //write to bit 3 of volatile configuration
    //register to enable xip
    unsigned int writebyte = 0xf3000000;
    unsigned int bits = 8;
    
    //execute WRITE ENABLE
	spifl_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
    
    spifl_executecommand(COMM_DTIN, writebyte, 0, (bits << 8) | WRITE_VOLCFGREG, NULL);
    return 1;
}

int spifl_terminateXipSequence()
{
    unsigned bits=0;
    unsigned frame= 0x0fd;
    unsigned int regvalue = 0;
    unsigned int numbits = 8;
    unsigned int bitmask = 0x08;

    /*if (spimode == QUAD)
        bits = 8;    
    else if (spimode == DUAL)
        bits = 13;
    else
        bits = 25;
*/
    bits = 25;
	spifl_executecommand(RECOVER_SEQ, 0, 0, (frame <<20 | bits << 8 | 0x00), NULL);
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
int spifl_memProgram(char* mem, int memsize, unsigned int address)
{
    //Check if erase needed
    //address should start at beginning of mem page
    //do while
    int pages_programmed = 0;
    //Command Config
    unsigned frame_struct = 0x000000a0;
    unsigned numbytes = 4;//max 4
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_QUADINEXT;

    unsigned int strtoProgram = 0;//must be at least 32 bits
    
    const int memblocks = memsize / numbytes;
    const int remainder_memblocks = memsize % numbytes;

    //Main programming cycle
    int i=0, j=0, k=0;
    unsigned int address_aux = address, statusReg=0;
    uint8_t statusRegByte = 0;
    int numbytes_aux = numbytes;
    for(i=0; i <= memblocks; i=i+numbytes){
        
        if (i==memblocks){
            if (remainder_memblocks == 0) break;
            else numbytes_aux = remainder_memblocks; 
        }
        else numbytes_aux = numbytes;

        //concat bytes into strtoProgram
        for(j=0, strtoProgram=0; j < numbytes_aux; j++){
            strtoProgram |= (mem[i+j] & 0x0ff) << (j*8); 
        }
	    
        statusReg = 0;
        //execute WRITE ENABLE
	    spifl_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
        //check if successfull? 
	    spifl_executecommand(COMMADDR_DTIN, strtoProgram, address_aux, command, NULL);
        //check if str programming completed
        for(k=0;k < 5; k++){//create end condition constant based on freqs
            //read status flags
            spifl_readStatusReg(&statusReg);   
            statusRegByte = 0xff000000 & statusReg;
            if((0x80 & statusRegByte) && !(0x10 & statusRegByte)) break;
            else{
                if(0x10 & statusReg) printf("programming word %x, address %x, index %d, statusReg %x\n", strtoProgram, address_aux, i, statusReg);
            }
        }
        
        address_aux += numbytes;

    }
    pages_programmed = ((address_aux-numbytes) - address) / page_size;
    return pages_programmed;

}

void spifl_writemem(unsigned int word, unsigned int address)
{
	//execute WRITE ENABLE
	spifl_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
	spifl_executecommand(COMMADDR_DTIN, word, address, PAGE_PROGRAM, NULL);
}

void spifl_programfastDualInput(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spifl_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x00000010;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_DUALIN;
	spifl_executecommand(COMMADDR_DTIN, word, address, command, NULL);
}

void spifl_programfastDualInputExt(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spifl_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x00000050;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_DUALINEXT;
	spifl_executecommand(COMMADDR_DTIN, word, address, command, NULL);
}

void spifl_programfastQuadInput(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spifl_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x00000020;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_QUADIN;
	spifl_executecommand(COMMADDR_DTIN, word, address, command, NULL);
}

void spifl_programfastQualInputExt(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spifl_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x000000a0;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_QUADINEXT;
	spifl_executecommand(COMMADDR_DTIN, word, address, command, NULL);
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
     spifl_executecommand(COMMANS, 0, 0, (numbits << 8) | READ_VOLCFGREG, regvalue);
     return 1;//Correct later
}

//Xip Read Commands
unsigned int spifl_readMemXip(unsigned address, unsigned activateXip)
{
    unsigned misobytes = 4, data=0;
    unsigned frame_struct = xipframestruct;//uint8 later
	unsigned dummy_cycles = 8;
    unsigned command = 0;
    unsigned xipbit = 1;
    
    if (activateXip == ACTIVEXIP || activateXip == TERMINATEXIP)// 2-> Activate/keep active, 3-> terminate Xip, others ignore
        xipbit = activateXip;
    else
        xipbit = 0;
    
    command = (xipbit << 30)|(frame_struct << 20)|(dummy_cycles<<16)|((misobytes*8)<<8)|0x00;
	
    spifl_executecommand(XIP_ADDRANS, 0, address, command, &data);
	return data;

}

//Read Memory Commands
unsigned int spifl_readfastDualOutput(unsigned address, unsigned activateXip)
{
    unsigned misobytes = 4, data=0;
    unsigned frame_struct = 0x00000004;//uint8 later
	unsigned dummy_cycles = 8;
    unsigned command = 0;
    unsigned xipbit = 1;
    
    if (activateXip == ACTIVEXIP || activateXip == TERMINATEXIP)// 2-> Activate/keep active, 3-> terminate Xip, others ignore
    {    
        xipbit = activateXip;
        xipframestruct = (activateXip == ACTIVEXIP) ? frame_struct: 0;
    }
    else
        xipbit = 0;
    
    command = (xipbit << 30)|(frame_struct<<20)|(dummy_cycles<<16)|((misobytes*8)<<8)|READFAST_DUALOUT;
	
    spifl_executecommand(COMMADDR_ANS, 0, address, command, &data);
	return data;
}

unsigned int spifl_readfastQuadOutput(unsigned address, unsigned activateXip)
{
    unsigned misobytes = 4, data=0;
    unsigned frame_struct = 0x00000008;//uint8 later
	unsigned dummy_cycles = 8;
    unsigned xipbit = 1;
    
    if (activateXip == ACTIVEXIP || activateXip == TERMINATEXIP)// 2-> Activate/keep active, 3-> terminate Xip, others ignore
    {    
        xipbit = activateXip;
        xipframestruct = (activateXip == ACTIVEXIP) ? frame_struct: 0;
    }
    else
        xipbit = 0;
    
    unsigned command = (xipbit << 30) | (frame_struct<<20)|(dummy_cycles<<16)|((misobytes*8)<<8)|READFAST_QUADOUT;
	
    spifl_executecommand(COMMADDR_ANS, 0, address, command, &data);
	return data;
}
unsigned int spifl_readfastDualInOutput(unsigned address, unsigned activateXip)
{
    unsigned misobytes = 4, data=0;
    unsigned frame_struct = 0x00000044;//uint8 later
	unsigned dummy_cycles = 8;
    unsigned xipbit = 1;
    
    if (activateXip == ACTIVEXIP || activateXip == TERMINATEXIP)// 2-> Activate/keep active, 3-> terminate Xip, others ignore
    {    
        xipbit = activateXip;
        xipframestruct = (activateXip == ACTIVEXIP) ? frame_struct: 0;
    }
    else
        xipbit = 0;
	
    unsigned command = (xipbit << 30) | (frame_struct<<20)|(dummy_cycles<<16)|((misobytes*8)<<8)|READFAST_DUALINOUT;
    spifl_executecommand(COMMADDR_ANS, 0, address, command, &data);
	return data;
}

unsigned int spifl_readfastQuadInOutput(unsigned address, unsigned activateXip)
{
    unsigned misobytes = 4, data=0;
    unsigned frame_struct = 0x00000088;//uint8 later
	unsigned dummy_cycles = 10;
    unsigned xipbit = 1;

    if (activateXip == ACTIVEXIP || activateXip == TERMINATEXIP)// 2-> Activate/keep active, 3-> terminate Xip, others ignore
    {    
        xipbit = activateXip;
        xipframestruct = (activateXip == ACTIVEXIP) ? frame_struct: 0;
    }
    else
        xipbit = 0;

    unsigned command = (xipbit << 30) | (frame_struct<<20)|(dummy_cycles<<16)|((misobytes*8)<<8)|READFAST_QUADINOUT;
	
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
