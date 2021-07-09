//Higher level functions

unsigned int spiflash_readStatusReg(unsigned *reg);
unsigned int spiflash_readVolConfigReg(unsigned *regvalue);

//xip functions
int spiflash_XipEnable();
int spiflash_terminateXipSequence();
unsigned int spiflash_readMemXip(unsigned address, unsigned activateXip);

//Reset
void spiflash_resetmem();
void spiflash_writemem(unsigned int word, unsigned int address);
unsigned int spiflash_readmem(unsigned int address);//extend for more than 4 bytes

// Erase memory functions
//extend for other erase type, ex bulk
void spiflash_erase_subsector(unsigned int subsector_address);
void spiflash_erase_sector(unsigned int sector_address);

//Fast Read functions
unsigned int spiflash_readFlashParam(unsigned address);
unsigned int spiflash_readfastDualOutput(unsigned address, unsigned activateXip);
unsigned int spiflash_readfastQuadOutput(unsigned address, unsigned activateXip);
unsigned int spiflash_readfastDualInOutput(unsigned address, unsigned activateXip);
unsigned int spiflash_readfastQuadInOutput(unsigned address, unsigned activateXip);

int spiflash_memProgram(char* mem, int memsize, unsigned int address);

void spiflash_programfastDualInput(unsigned int word, unsigned address);
void spiflash_programfastDualInputExt(unsigned int word, unsigned address);
void spiflash_programfastQuadInput(unsigned int word, unsigned address);
void spiflash_programfastQuadInputExt(unsigned int word, unsigned address);
//wear-leveling
//set DIV
//set num bytes in and out, aligned, padded?
