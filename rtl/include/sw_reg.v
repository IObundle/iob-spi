//SW_REG
//soft reset register FLC_RESET
`SWREG_W(FL_RESET,			1,	0)//FL soft reset
`SWREG_W(FL_DATAIN,			32,	0)//FL data_in
`SWREG_W(FL_ADDRESS,		24,	0)//FL address
`SWREG_W(FL_COMMAND,		8,	0)//FL command
`SWREG_W(FL_COMMANDTP,		3,	0)//FL command type
`SWREG_W(FL_VALIDFLG,		1,	0)//FL valigflag
`SWREG_R(FL_DATAOUT,		32,	0)//FL data_out
`SWREG_R(FL_VALIDFLGOUT,	1,	0)//FL valigflag_out
//`SWREG_R(FL_TREADY,			1,	0)//FL tready
//
