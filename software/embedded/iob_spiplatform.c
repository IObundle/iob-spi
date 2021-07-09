#include <stddef.h>
#include "iob_spiplatform.h"
#include "SPIsw_reg.h"
#include "interconnect.h"
#include "iob_spidefs.h"
#include "stdint.h"

static unsigned int base;
//create another static variable for upper addresses
//SET
void spiflash_reset()
{
	IO_SET(base, FL_RESET, 1);//soft reset
	IO_SET(base, FL_RESET, 0);
}

void spiflash_setDATAIN(unsigned int datain)
{
	IO_SET(base, FL_DATAIN, datain);

}

void spiflash_setADDRESS(unsigned int address)
{
	IO_SET(base, FL_ADDRESS, address);
}

void spiflash_setCOMMAND(unsigned int command)
{
	IO_SET(base, FL_COMMAND, command);
}

void spiflash_setCOMMTYPE(unsigned int commtype)
{
	IO_SET(base, FL_COMMANDTP, commtype);
}

void spiflash_setVALIDIN(unsigned int validin)
{
	IO_SET(base, FL_VALIDFLG, validin);
}

//GET
unsigned int spiflash_getDATAOUT()
{
	unsigned int dataout;
	dataout = (unsigned int) IO_GET(base, FL_DATAOUT);
	return dataout;
}

inline unsigned spiflash_getREADY()
{
    return (unsigned int) IO_GET(base, FL_READY);
}

unsigned int spiflash_getVALIDOUT()
{
	unsigned int validout;
	validout = (unsigned int) IO_GET(base, FL_VALIDFLGOUT);
	return validout;
}

//Higher functions
void spiflash_init(int base_address)
{
	base = base_address;
	spiflash_reset();
	//spiflash_resetmem();
}
void spiflash_waitvalidout()
{
	while(!IO_GET(base, FL_VALIDFLGOUT));//not using wrapper getter
}

void spiflash_executecommand(int typecode, unsigned int datain, unsigned int address, unsigned int command, unsigned *dataout)
{
	spiflash_setCOMMAND(command);
	spiflash_setCOMMTYPE(typecode);
    while((!spiflash_getREADY()));
	
	switch(typecode)
	{
		case COMM:
				spiflash_setVALIDIN(1);
				//spiflash_waitvalidout();
				spiflash_setVALIDIN(0);
				//deassert valid?
				break;
		case COMMANS:
				spiflash_setVALIDIN(1);
				spiflash_setVALIDIN(0);
				//spiflash_waitvalidout();
                while(!spiflash_getREADY());
				*dataout = spiflash_getDATAOUT();
				break;
		case COMMADDR_ANS:
				spiflash_setADDRESS(address);
				spiflash_setVALIDIN(1);
				spiflash_setVALIDIN(0);
                while(!spiflash_getREADY());
				//spiflash_waitvalidout();
				*dataout = spiflash_getDATAOUT();
				break;
		case COMM_DTIN:
				spiflash_setDATAIN(datain);
				spiflash_setVALIDIN(1);
				//spiflash_waitvalidout();
				spiflash_setVALIDIN(0);
				break;
		case COMMADDR_DTIN:
				spiflash_setADDRESS(address);
				spiflash_setDATAIN(datain);
				spiflash_setVALIDIN(1);
				//spiflash_waitvalidout();
				spiflash_setVALIDIN(0);
				break;
		case COMMADDR:
				spiflash_setADDRESS(address);
				spiflash_setVALIDIN(1);
				//spiflash_waitvalidout();
				spiflash_setVALIDIN(0);
				break;
        case XIP_ADDRANS:
				spiflash_setADDRESS(address);
				spiflash_setVALIDIN(1);
				spiflash_setVALIDIN(0);
                while(!spiflash_getREADY());
				*dataout = spiflash_getDATAOUT();
                break;
        case RECOVER_SEQ:
				spiflash_setDATAIN(datain);
				spiflash_setVALIDIN(1);
				spiflash_setVALIDIN(0);
                break;
		default:
				spiflash_setVALIDIN(1);
				spiflash_setVALIDIN(0);

	}
}

