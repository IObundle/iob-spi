//SW_REG
//soft reset register FLC_RESET
reg           FL_RESET;//FL soft reset
reg [32-1:0]  FL_DATAIN;//FL data_in
reg [32-1:0]  FL_ADDRESS;//FL address
reg [32-1:0]  FL_COMMAND;//FL command
reg [32-1:0]  FL_COMMANDTP;//FL command type
reg           FL_VALIDFLG;//FL valigflag
wire          FL_READY;//FL ready flag
wire [32-1:0] FL_DATAOUT;//FL data_out
