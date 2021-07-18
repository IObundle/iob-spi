#include <stddef.h>
#include "iob_spi.h"
#include "iob_spiplatform.h"
#include "iob_spidefs.h"
#include "stdint.h"
#include "printf.h"

static unsigned int base;
unsigned xipframestruct = 0;
unsigned commtypeReg = 0;

//Xip functions
int spiflash_XipEnable()
{
    //write to bit 3 of volatile configuration
    //register to enable xip
    unsigned int writebyte = 0x000000f3;
    unsigned int bits = 8;
    
    //execute WRITE ENABLE
	spiflash_executecommand(commtypeReg|COMM, 0, 0, WRITE_ENABLE, NULL);
    
    spiflash_executecommand(commtypeReg|COMM_DTIN, writebyte, 0, (bits << 8) | WRITE_VOLCFGREG, NULL);
    return 1;
}

int spiflash_terminateXipSequence()
{
    unsigned bits=0;
    unsigned frame= 0x0fd;
    uint8_t currentmode = commtypeReg & (0x3<<30);

    if (currentmode == 0 || currentmode == QUADMODE) bits = 7;
    else if (currentmode == DUALMODE) bits = 13;
    else bits = 25;

	spiflash_executecommand(commtypeReg|RECOVER_SEQ, 0, 0, (frame <<20 | bits << 8 | 0x00), NULL);
    return 0;
}

void spiflash_RecoverSequence()
{
    unsigned bits=7;
    unsigned frame=0x07d;
    // Power Loss Recover Sequence 
    // 1st part
	spiflash_executecommand(RECOVER_SEQ, 0, 0, (frame <<20 | bits << 8 | 0x00), NULL);
    bits = 9;
	spiflash_executecommand(RECOVER_SEQ, 0, 0, (frame <<20 | bits << 8 | 0x00), NULL);
    bits = 13;
	spiflash_executecommand(RECOVER_SEQ, 0, 0, (frame <<20 | bits << 8 | 0x00), NULL);
    bits = 17;
	spiflash_executecommand(RECOVER_SEQ, 0, 0, (frame <<20 | bits << 8 | 0x00), NULL);
    bits = 25;
	spiflash_executecommand(RECOVER_SEQ, 0, 0, (frame <<20 | bits << 8 | 0x00), NULL);
    bits = 33;
	spiflash_executecommand(RECOVER_SEQ, 0, 0, (frame <<20 | bits << 8 | 0x00), NULL);
    
    // 2nd part
    bits = 8;
	spiflash_executecommand(commtypeReg|RECOVER_SEQ, 0, 0, (frame <<20 | bits << 8 | 0x00), NULL);
}

/*
//Enter 4 byte addr mode 
void enter4byteAddrMode()
{
    //execute WRITE ENABLE
	spiflash_executecommand(commtypeReg|COMM, 0, 0, WRITE_ENABLE, NULL);
    //Activate 4 byte addr mode
    spiflash_executecommand(commtypeReg|COMM, 0, 0, ENTER4BYTEADDR, NULL);
    commtypeReg |= (0x1 << 21); // set bit 
}

//Exit 4 byte addr mode
void exit4byteAddrMode()
{
    //execute WRITE ENABLE
	spiflash_executecommand(commtypeReg|COMM, 0, 0, WRITE_ENABLE, NULL);
    //Activate 4 byte addr mode
    spiflash_executecommand(commtypeReg|COMM, 0, 0, EXIT4BYTEADDR, NULL);
    // affect input sw reg
    commtypeReg &= ~(0x1 << 21); // clear 4 byte addr enable bit 
}
*/

void enterSPImode(int spimode)
{
    //Read Enhanced Volatile Register state
    unsigned enhancedReg = 0;
   	unsigned bytes = 1;
    unsigned command_aux = ((bytes*8)<<8)|READENHANCEDREG;
	spiflash_executecommand(commtypeReg|COMMANS, 0, 0, command_aux, &enhancedReg);
    //Enhanced volatile Reg state in least significant byte
     
    //New mode
    unsigned int newRegVal = 0;
    unsigned int newbits = (spimode == QUADMODE) ? 0x80 : (spimode == DUALMODE) ? 0x40 : 0xC0;
    newRegVal = (enhancedReg & ~(0xC0)) | newbits; 

    //execute Write Enable
	spiflash_executecommand(commtypeReg|COMM, 0, 0, WRITE_ENABLE, NULL);

    //execute Write to enhanced register
    command_aux = ((bytes*8)<<8)|WRITEENHANCEDREG;
    spiflash_executecommand(commtypeReg|COMM_DTIN, newRegVal, 0, command_aux, NULL);
    // Verify if successfull 
    //update config
    commtypeReg &= ~(0x3 << 30); //Clear
    commtypeReg |= (spimode == QUADMODE) ? (0x2 << 30) : (spimode == DUALMODE) ? (0x1 << 30) : 0x00; //Set bits

}

//Reset commands
void spiflash_resetmem()
{
	//execute RESET ENABLE
	spiflash_executecommand(commtypeReg|COMM, 0, 0, RESET_ENABLE, NULL);
	//execute RESET MEM
	spiflash_executecommand(commtypeReg|COMM, 0, 0, RESET_MEM, NULL);
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
/*
void spiflash_writemem(unsigned int word, unsigned int address)
{
	//execute WRITE ENABLE
	spiflash_executecommand(commtypeReg|COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
	spiflash_executecommand(commtypeReg|COMMADDR_DTIN, word, address, PAGE_PROGRAM, NULL);
}
*/
/*void spiflash_programfastDualInput(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spiflash_executecommand(commtypeReg|COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x00000010;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_DUALIN;
	spiflash_executecommand(commtypeReg|COMMADDR_DTIN, word, address, command, NULL);
}

void spiflash_programfastDualInputExt(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spiflash_executecommand(commtypeReg|COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x00000050;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_DUALINEXT;
	spiflash_executecommand(commtypeReg|COMMADDR_DTIN, word, address, command, NULL);
}

void spiflash_programfastQuadInput(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spiflash_executecommand(commtypeReg|COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x00000020;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_QUADIN;
	spiflash_executecommand(commtypeReg|COMMADDR_DTIN, word, address, command, NULL);
}
*/
void spiflash_programfastQuadInputExt(unsigned int word, unsigned address)
{
	//execute WRITE ENABLE
	spiflash_executecommand(commtypeReg|COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute PAGE PROGRAM
    unsigned frame_struct = 0x000000a0;
    unsigned numbytes = 4;
    unsigned command = (frame_struct << 20) | (numbytes*8 << 8) | PROGRAMFAST_QUADINEXT;
	spiflash_executecommand(commtypeReg|COMMADDR_DTIN, word, address, command, NULL);
}

//Read Register Commands
unsigned int spiflash_readStatusReg(unsigned *regstatus)
{
     unsigned int bytes = 1;
     spiflash_executecommand(commtypeReg|COMMANS, 0, 0,((bytes*8)<<8)| READ_STATUSREG, regstatus);
     return 1;//Correct later
}

//Read Volatile Configuration Register
unsigned int spiflash_readVolConfigReg(unsigned *regvalue)
{
     unsigned int numbits = 8;
     spiflash_executecommand(commtypeReg|COMMANS, 0, 0, (numbits << 8) | READ_VOLCFGREG, regvalue);
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
	
    spiflash_executecommand(commtypeReg|XIP_ADDRANS, 0, address, command, &data);
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
	
    spiflash_executecommand(commtypeReg|COMMADDR_ANS, 0, address, command, &data);
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
	
    spiflash_executecommand(commtypeReg|COMMADDR_ANS, 0, address, command, &data);
	return data;
}
unsigned int spiflash_readfastDualInOutput(unsigned address, unsigned activateXip)
{
    unsigned misobytes = 4, data=0;
    unsigned frame_struct = 0x00000044;//uint8 later
	unsigned dummy_cycles = 8;
    unsigned xipbit = 1;

    // 2-> Activate/keep active, 3-> terminate Xip, others ignore
    if (activateXip == ACTIVEXIP || activateXip == TERMINATEXIP)
    {    
        xipbit = activateXip;
        xipframestruct = (activateXip == ACTIVEXIP) ? frame_struct: 0;
    }
    else
        xipbit = 0;
	
    unsigned command = (xipbit << 30) | (frame_struct<<20)|(dummy_cycles<<16)|((misobytes*8)<<8)|READFAST_DUALINOUT;
    spiflash_executecommand(commtypeReg|COMMADDR_ANS, 0, address, command, &data);
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
	
    spiflash_executecommand(commtypeReg|COMMADDR_ANS, 0, address, command, &data);
	return data;
}

unsigned int spiflash_readmem(unsigned int address)
{
	unsigned int data;	
	//execute READ
	unsigned bytes = 4;
	spiflash_executecommand(commtypeReg|COMMADDR_ANS, 0, address, ((bytes*8)<<8)|READ, &data);
	return data;
}
/*
unsigned int spiflash_readfastDTR(unsigned address)
{
    unsigned int data;
    unsigned int bytes = 4;
    unsigned int dummy_cycles = 6;
    unsigned int frame_struct = 0;
    unsigned int command = (frame_struct<<20)|(dummy_cycles<<16)|((bytes*8)<<8)|READFAST_DTR;
    spiflash_executecommand(commtypeReg|COMMADDR_ANS, 0, address, command, &data);
    return data;
}

unsigned int spiflash_readfastDualOutDTR(unsigned address)
{
    unsigned int data;
    unsigned int bytes = 4;
    unsigned int dummy_cycles = 6;
    unsigned int frame_struct = 0x4;
    unsigned int command = (frame_struct<<20)|(dummy_cycles<<16)|((bytes*8)<<8)|READFAST_DUALOUTDTR;
    spiflash_executecommand(commtypeReg|COMMADDR_ANS, 0, address, command, &data);
    return data;
}

unsigned int spiflash_readfastDualIODTR(unsigned address)
{
    unsigned int data;
    unsigned int bytes = 4;
    unsigned int dummy_cycles = 6;
    unsigned int frame_struct = 0x44;
    unsigned int command = (frame_struct<<20)|(dummy_cycles<<16)|((bytes*8)<<8)|READFAST_DUALIODTR;
    spiflash_executecommand(commtypeReg|COMMADDR_ANS, 0, address, command, &data);
    return data;
}

unsigned int spiflash_readfastQuadOutDTR(unsigned address)
{
    unsigned int data;
    unsigned int bytes = 4;
    unsigned int dummy_cycles = 6;
    unsigned int frame_struct = 0x8;
    unsigned int command = (frame_struct<<20)|(dummy_cycles<<16)|((bytes*8)<<8)|READFAST_QUADOUTDTR;
    spiflash_executecommand(commtypeReg|COMMADDR_ANS, 0, address, command, &data);
    return data;
}
*/
unsigned int spiflash_readfastQuadIODTR(unsigned int address)
{
    unsigned int data;
    unsigned int bytes = 4;
    unsigned int dummy_cycles = 8;
    unsigned int frame_struct = 0x88;
    unsigned int command = (frame_struct<<20)|(dummy_cycles<<16)|((bytes*8)<<8)|READFAST_QUADIODTR;
    unsigned int dtr_bit = 0x1 << 20;
    spiflash_executecommand(commtypeReg|COMMADDR_ANS|dtr_bit, 0, address, command, &data);
    return data;
}


unsigned int spiflash_readFlashParam(unsigned address)
{
	unsigned int data;
	unsigned bytes = 4;
	unsigned dummy_cycles = 8;
	spiflash_executecommand(commtypeReg|COMMADDR_ANS, 0, address, (dummy_cycles<<16)|((bytes*8)<<8)|READ_FLPARAMS, &data);
	return data;
}

//Erase Memory commands
void spiflash_erase_subsector(unsigned int subsector_address)
{
    //write enable
    spiflash_executecommand(commtypeReg|COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute ERASE
	spiflash_executecommand(commtypeReg|COMMADDR, 0, subsector_address,SUB_ERASE, NULL);
}

void spiflash_erase_sector(unsigned int sector_address)
{
    //Write Enable	
    spiflash_executecommand(commtypeReg|COMM, 0, 0, WRITE_ENABLE, NULL);
	//execute ERASE
	spiflash_executecommand(commtypeReg|COMMADDR, 0, sector_address,SEC_ERASE, NULL);
}
