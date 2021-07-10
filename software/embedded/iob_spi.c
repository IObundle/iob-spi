#include <stddef.h>
#include "iob_spi.h"
#include "iob_spiplatform.h"
#include "iob_spidefs.h"
#include "stdint.h"
#include "printf.h"

static unsigned int base;
//create another static variable for upper addresses

static unsigned xipframestruct = 0;

//Xip functions
int spiflash_XipEnable()
{
    //write to bit 3 of volatile configuration
    //register to enable xip
    unsigned int writebyte = 0x000000f3;
    unsigned int bits = 8;
    
    //execute WRITE ENABLE
	spiflash_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
    
    spiflash_executecommand(COMM_DTIN, writebyte, 0, (bits << 8) | WRITE_VOLCFGREG, NULL);
    return 1;
}

int spiflash_terminateXipSequence()
{
    unsigned bits=0;
    unsigned frame= 0x0fd;
    unsigned int regvalue = 0;
    unsigned int numbits = 8;
    unsigned int bitmask = 0x08;

    bits = 25;
	spiflash_executecommand(RECOVER_SEQ, 0, 0, (frame <<20 | bits << 8 | 0x00), NULL);
    //Read volatile register to check if xip succesfully terminated
    spiflash_readVolConfigReg(&regvalue);

    //Check for specific xip bit [3]
    if(bitmask & regvalue)
        return 1;
    else
        return 0;
}

//Reset commands
void spiflash_resetmem()
{
	//execute RESET ENABLE
	spiflash_executecommand(COMM, 0, 0, RESET_ENABLE, NULL);
	//execute RESET MEM
	spiflash_executecommand(COMM, 0, 0, RESET_MEM, NULL);
}

//Program/Write Memory commands
int spiflash_memProgram(char* mem, int memsize, unsigned int address)
{
    //Check if erase needed
    //address should start at beginning of mem page
    //do while
    int pages_programmed = 0;
    unsigned read_word= 0;
    //Command Config
    unsigned frame_struct = 0x000000a0;
    unsigned numbytes = 4;//max 4
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_QUADINEXT;

    unsigned int strtoProgram = 0;//must be at least 32 bits
    
    int memblocks = memsize / numbytes;
    int remainder_memblocks = memsize % numbytes;
    printf("Entering programming cycle %d\n", memblocks);
    //Main programming cycle
    int i=0, j=0, k=0;
    unsigned int address_aux = address, statusReg=0;
    int l=0;
    int numbytes_aux = numbytes;
    //printf("after static allocations\n");
    //for(i=0; i <= memblocks; i=i+numbytes_aux){
    for(i=0; i < memsize; i=i+numbytes_aux){
        //printf("in for\n"); 
        if (i==memblocks){
            if (remainder_memblocks == 0) break;
            else{ 
                numbytes_aux = remainder_memblocks; 
                command = 0;
                command = (frame_struct << 20) | (numbytes_aux*8 << 8) | PROGRAMFAST_QUADINEXT;
            }
        }
        else numbytes_aux = numbytes;
        
        //printf("after numbytes\n");
        //printf("%c\n", mem[i]);
        //concat bytes into strtoProgram
        for(j=0, strtoProgram=0; j < numbytes_aux; j++){
            //printf("%c ,  %x\n", mem[i+j], (unsigned int)mem[i+j]);
            strtoProgram |= ((unsigned int)mem[i+j] & 0x0ff) << (j*8); 
        }
        //printf("numbytes %d\n", numbytes_aux);
        //printf("str: %x\n", strtoProgram);
        //printf("after concat\n");
	    
        statusReg = 0;
        //execute WRITE ENABLE
	    spiflash_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
        //printf("after write enable\n");
        //check if successfull? 
	    spiflash_executecommand(COMMADDR_DTIN, strtoProgram, address_aux, command, NULL);
        //printf("after command sent\n");
        //check if str programming completed
        
        spiflash_readStatusReg(&statusReg);
        //printf("\tstatus:%x\n", statusReg);
        if(statusReg != 0){
            do{
                spiflash_readStatusReg(&statusReg);
                l++;
            }while(statusReg != 0 && l<2);
        }
        l=0;

        //read_word = spiflash_readfastQuadOutput(address_aux, 0);
       //printf("Programmed: %x, read: %x\n", strtoProgram, read_word); 
        address_aux += numbytes_aux;

    }
    return address_aux; 

}

void spiflash_writemem(unsigned int word, unsigned int address)
{
	//execute WRITE ENABLE
	spiflash_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
	spiflash_executecommand(COMMADDR_DTIN, word, address, PAGE_PROGRAM, NULL);
}

void spiflash_programfastDualInput(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spiflash_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x00000010;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_DUALIN;
	spiflash_executecommand(COMMADDR_DTIN, word, address, command, NULL);
}

void spiflash_programfastDualInputExt(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spiflash_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x00000050;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_DUALINEXT;
	spiflash_executecommand(COMMADDR_DTIN, word, address, command, NULL);
}

void spiflash_programfastQuadInput(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spiflash_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x00000020;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_QUADIN;
	spiflash_executecommand(COMMADDR_DTIN, word, address, command, NULL);
}

void spiflash_programfastQuadInputExt(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spiflash_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x000000a0;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_QUADINEXT;
	spiflash_executecommand(COMMADDR_DTIN, word, address, command, NULL);
}

//Read Register Commands
unsigned int spiflash_readStatusReg(unsigned *regstatus)
{
     unsigned int bytes = 1;
     spiflash_executecommand(COMMANS, 0, 0,((bytes*8)<<8)| READ_STATUSREG, regstatus);
     return 1;//Correct later
}

//Read Volatile Configuration Register
unsigned int spiflash_readVolConfigReg(unsigned *regvalue)
{
     unsigned int numbits = 8;
     spiflash_executecommand(COMMANS, 0, 0, (numbits << 8) | READ_VOLCFGREG, regvalue);
     return 1;//Correct later
}

//Xip Read Commands
unsigned int spiflash_readMemXip(unsigned address, unsigned activateXip)
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
    
    command = (xipbit << 30)|(frame_struct << 20)|(dummy_cycles<<16)|((misobytes*8)<<8)|0x00;//check
	
    spiflash_executecommand(XIP_ADDRANS, 0, address, command, &data);
	return data;

}

//Read Memory Commands
unsigned int spiflash_readfastDualOutput(unsigned address, unsigned activateXip)
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
	
    spiflash_executecommand(COMMADDR_ANS, 0, address, command, &data);
	return data;
}

unsigned int spiflash_readfastQuadOutput(unsigned address, unsigned activateXip)
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
	
    spiflash_executecommand(COMMADDR_ANS, 0, address, command, &data);
	return data;
}
unsigned int spiflash_readfastDualInOutput(unsigned address, unsigned activateXip)
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
    spiflash_executecommand(COMMADDR_ANS, 0, address, command, &data);
	return data;
}

unsigned int spiflash_readfastQuadInOutput(unsigned address, unsigned activateXip)
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
	
    spiflash_executecommand(COMMADDR_ANS, 0, address, command, &data);
	return data;
}

unsigned int spiflash_readmem(unsigned int address)
{
	unsigned int data;	
	//execute READ
	unsigned bytes = 4;
	spiflash_executecommand(COMMADDR_ANS, 0, address, ((bytes*8)<<8)|READ, &data);
	return data;
}

unsigned int spiflash_readFlashParam(unsigned address)
{
	unsigned int data;
	unsigned bytes = 4;
	unsigned dummy_cycles = 8;
	spiflash_executecommand(COMMADDR_ANS, 0, address, (dummy_cycles<<16)|((bytes*8)<<8)|READ_FLPARAMS, &data);
	return data;
}

//Erase Memory commands
void spiflash_erase_subsector(unsigned int subsector_address)
{
    //write enable
    spiflash_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute ERASE
	spiflash_executecommand(COMMADDR, 0, subsector_address,SUB_ERASE, NULL);
}

void spiflash_erase_sector(unsigned int sector_address)
{
    //Write Enable	
    spiflash_executecommand(COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute ERASE
	spiflash_executecommand(COMMADDR, 0, sector_address,SEC_ERASE, NULL);
}
