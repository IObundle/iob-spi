//Higher level functions

unsigned int spifl_readStatusReg(unsigned *reg);
unsigned int spifl_readVolConfigReg(unsigned *regvalue);

//xip functions
int spifl_XipEnable();
int spifl_terminateXipSequence();

void spifl_resetmem();
void spifl_writemem(unsigned int word, unsigned int address);
unsigned int spifl_readmem(unsigned int address);//extend for more than 4 bytes
void spifl_erasemem(unsigned int subsector_address);//extend for other erase type, ex bulk
unsigned int spifl_readFlashParam(unsigned address);
unsigned int spifl_readfastDualOutput(unsigned address, unsigned activateXip);
unsigned int spifl_readfastQuadOutput(unsigned address);
unsigned int spifl_readfastDualInOutput(unsigned address);

//wear-leveling
//set DIV
//set num bytes in and out, aligned, padded?
