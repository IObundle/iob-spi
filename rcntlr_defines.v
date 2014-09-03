/*
 * rcntlr constant definitions
 */
//test definitions
//test modes
`define SENDBYTE 1'b0 //sends byte at input
`define SENDSEQ 1'b1 //sends byte counting sequence 8'd 0-255

`define WHITE_DIS //disable whitening for testing

`define INPWORD 8'hEC //Input word for SENDBYTE test mode: 1110 1100
`define CNTW 8 //counting sequence width
`define CHIDX 6 //channel id used for tests; 
                // LSB is zero so that preamble find code does not need to change                // when Address Address is supported 
/* Only even channels supported so far because in this case bit 6 of the 
 whitening LFSR is always 0 and does not invert the first bit after the 
 preamble. Recall that the preamble has been chosen such that its last bit sent
 equals the first bit of the data. */
`define TEST0DATABITS 24
`define NRANDOMBITS 256


//core definitions
`define LOG_N_REGISTERS 7 // number of configuration registers 

`define LOG_FREQ 4 //log of frequency in megaherts

`define DATA_WIDTH 8

`define PKTCNTW 6
`define MAXPKTSIZE 39

//the following two are related by clog2
`define MAXDATABITS 312 //BLE specifies a maximum of 39 bytes (312 bits) per packet 
`define BITCNTW 9 //bit counter width

`define PREAMBLE_MSB0 8'b01010101
`define PREAMBLE_MSB1 8'b10101010

`define CHIDXW 6 // channel id width
