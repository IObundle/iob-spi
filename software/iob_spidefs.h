
//TYPECODES identify type of operation to be executed by flash controller

#define COMM			0
#define COMMANS			1
#define COMMADDR_ANS	2
#define COMM_DTIN		3
#define COMMADDR_DTIN	4
#define COMMADDR		5

//FLASH MEM internal command codes
#define RESET_ENABLE		0x66
#define	RESET_MEM			0x99
#define READ				0x03
#define WRITE_ENABLE		0x06
#define PAGE_PROGRAM		0x02
#define SUB_ERASE			0x20
#define READ_STATUSREG      0x05
#define READ_ID				0x9f
#define READ_FLPARAMS       0x5A
#define READFAST_DUALOUT    0x3B   
#define READFAST_DUALINOUT  0XBB
