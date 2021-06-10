//Higher level functions

unsigned int spifl_readStatusReg(unsigned *reg);
unsigned int spifl_readVolConfigReg(unsigned *regvalue);

//xip functions
int spifl_XipEnable();
int spifl_terminateXipSequence();
unsigned int spifl_readMemXip(unsigned address, unsigned activateXip);

//Reset
void spifl_resetmem();
void spifl_writemem(unsigned int word, unsigned int address);
unsigned int spifl_readmem(unsigned int address);//extend for more than 4 bytes

// Erase memory functions
//extend for other erase type, ex bulk
void spifl_erase_subsector(unsigned int subsector_address);
void spifl_erase_sector(unsigned int sector_address);

//Fast Read functions
unsigned int spifl_readFlashParam(unsigned address);
unsigned int spifl_readfastDualOutput(unsigned address, unsigned activateXip);
unsigned int spifl_readfastQuadOutput(unsigned address, unsigned activateXip);
unsigned int spifl_readfastDualInOutput(unsigned address, unsigned activateXip);
unsigned int spifl_readfastQuadInOutput(unsigned address, unsigned activateXip);

int spifl_memProgram(char* mem, int memsize, unsigned int address);

void spifl_programfastDualInput(unsigned int word, unsigned address);
void spifl_programfastDualInputExt(unsigned int word, unsigned address);
void spifl_programfastQuadInput(unsigned int word, unsigned address);
void spifl_programfastQuadInputExt(unsigned int word, unsigned address);
//wear-leveling
//set DIV
//set num bytes in and out, aligned, padded?
