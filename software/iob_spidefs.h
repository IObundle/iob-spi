
//TYPECODES identify type of operation to be executed by flash controller

#define COMM			0
#define COMMANS			1
#define COMMADDR_ANS	2
#define COMM_DTIN		3
#define COMMADDR_DTIN	4
#define COMMADDR		5
#define XIP_ADDRANS     6
#define RECOVER_SEQ     7

//
#define ACTIVEXIP   2
#define TERMINATEXIP    3

//FLASH MEM internal command codes
#define RESET_ENABLE		0x66
#define	RESET_MEM			0x99
#define READ				0x03
#define WRITE_ENABLE		0x06
#define WRITE_VOLCFGREG     0x81
#define PAGE_PROGRAM		0x02
#define SUB_ERASE			0x20
#define READ_STATUSREG      0x05
#define READ_VOLCFGREG      0x85
#define READ_ID				0x9f
#define READ_FLPARAMS       0x5A
#define READFAST_DUALOUT    0x3B   
#define READFAST_QUADOUT    0x6B   
#define READFAST_DUALINOUT  0xbb
#define READFAST_QUADINOUT  0xeb
