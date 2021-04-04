//Higher level functions

unsigned int spifl_readStatusReg(unsigned *reg);
void spifl_resetmem();
void spifl_writemem(unsigned int word, unsigned int address);
unsigned int spifl_readmem(unsigned int address);//extend for more than 4 bytes
void spifl_erasemem(unsigned int subsector_address);//extend for other erase type, ex bulk
unsigned int spifl_readFlashParam(unsigned address);
unsigned int spifl_readfastDualOutput(unsigned address);
unsigned int spifl_readfastQuadOutput(unsigned address);
unsigned int spifl_readfastDualInOutput(unsigned address);

//wear-leveling
//set DIV
//set num bytes in and out, aligned, padded?
