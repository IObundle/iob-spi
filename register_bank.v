
`timescale 1ns/1ps
`include "rcntlr_defines.v"

module register_bank (
  input		    clk,
  input  	    rst,
  input             wr,
  input    [`LOG_N_REGISTERS-1:0] address,     
  input    [`DATA_WIDTH-1:0] data_in,   
  output [2**`LOG_N_REGISTERS * `DATA_WIDTH - 1 :0] chip_out,    
  output wire [`DATA_WIDTH-1:0] data_out    
);

reg [7:0] my_bank [127:0];
integer i;

genvar j;

generate

   for (j= 0; j < 2**`LOG_N_REGISTERS; j=j+1) begin : chip_out_gen
	assign chip_out[(j+1) * `DATA_WIDTH - 1 -: `DATA_WIDTH] = my_bank[j][`DATA_WIDTH -1 -: `DATA_WIDTH ];

   end

endgenerate 

assign data_out = my_bank[address];

/*always @(address) begin
	case (address) 
		0: data_out = my_bank[0];
		1: data_out = my_bank[1];
		2: data_out = my_bank[2];
		3: data_out = my_bank[3];
		4: data_out = my_bank[4];
		5: data_out = my_bank[5];
		6: data_out = my_bank[6];
		7: data_out = my_bank[7];
		8: data_out = my_bank[8];
		9: data_out = my_bank[9];
		10: data_out = my_bank[10];
		11: data_out = my_bank[11];
		12: data_out = my_bank[12];
		13: data_out = my_bank[13];
		14: data_out = my_bank[14];
		15: data_out = my_bank[15];
		16: data_out = my_bank[16];
		17: data_out = my_bank[17];
		18: data_out = my_bank[18];
		19: data_out = my_bank[19];
		20: data_out = my_bank[20];
		21: data_out = my_bank[21];
		22: data_out = my_bank[22];
		23: data_out = my_bank[23];
		24: data_out = my_bank[24];
		25: data_out = my_bank[25];
		26: data_out = my_bank[26];
		27: data_out = my_bank[27];
		28: data_out = my_bank[28];
		29: data_out = my_bank[29];
		30: data_out = my_bank[30];
		31: data_out = my_bank[31];
		32: data_out = my_bank[32];
		33: data_out = my_bank[33];
		34: data_out = my_bank[34];
		35: data_out = my_bank[35];
		36: data_out = my_bank[36];
		37: data_out = my_bank[37];
		38: data_out = my_bank[38];
		39: data_out = my_bank[39];
		40: data_out = my_bank[40];
		41: data_out = my_bank[41];
		42: data_out = my_bank[42];
		43: data_out = my_bank[43];
		44: data_out = my_bank[44];
		45: data_out = my_bank[45];
		46: data_out = my_bank[46];
		47: data_out = my_bank[47];
		48: data_out = my_bank[48];
		49: data_out = my_bank[49];
		50: data_out = my_bank[50];
		51: data_out = my_bank[51];
		52: data_out = my_bank[52];
		53: data_out = my_bank[53];
		54: data_out = my_bank[54];
		55: data_out = my_bank[55];
		56: data_out = my_bank[56];
		57: data_out = my_bank[57];
		58: data_out = my_bank[58];
		59: data_out = my_bank[59];
		60: data_out = my_bank[60];
		61: data_out = my_bank[61];
		62: data_out = my_bank[62];
		63: data_out = my_bank[63];
		64: data_out = my_bank[64];
		65: data_out = my_bank[65];
		66: data_out = my_bank[66];
		67: data_out = my_bank[67];
		68: data_out = my_bank[68];
		69: data_out = my_bank[69];
		70: data_out = my_bank[70];
		71: data_out = my_bank[71];
		72: data_out = my_bank[72];
		73: data_out = my_bank[73];
		74: data_out = my_bank[74];
		75: data_out = my_bank[75];
		76: data_out = my_bank[76];
		77: data_out = my_bank[77];
		78: data_out = my_bank[78];
		79: data_out = my_bank[79];
		80: data_out = my_bank[80];
		81: data_out = my_bank[81];
		82: data_out = my_bank[82];
		83: data_out = my_bank[83];
		84: data_out = my_bank[84];
		85: data_out = my_bank[85];
		86: data_out = my_bank[86];
		87: data_out = my_bank[87];
		88: data_out = my_bank[88];
		89: data_out = my_bank[89];
		90: data_out = my_bank[90];
		91: data_out = my_bank[91];
		92: data_out = my_bank[92];
		93: data_out = my_bank[93];
		94: data_out = my_bank[94];
		95: data_out = my_bank[95];
		96: data_out = my_bank[96];
		97: data_out = my_bank[97];
		98: data_out = my_bank[98];
		99: data_out = my_bank[99];
		100: data_out = my_bank[100];
		101: data_out = my_bank[101];
		102: data_out = my_bank[102];
		103: data_out = my_bank[103];
		104: data_out = my_bank[104];
		105: data_out = my_bank[105];
		106: data_out = my_bank[106];
		107: data_out = my_bank[107];
		108: data_out = my_bank[108];
		109: data_out = my_bank[109];
		110: data_out = my_bank[110];
		111: data_out = my_bank[111];
		112: data_out = my_bank[112];
		113: data_out = my_bank[113];
		114: data_out = my_bank[114];
		115: data_out = my_bank[115];
		116: data_out = my_bank[116];
		117: data_out = my_bank[117];
		118: data_out = my_bank[118];
		119: data_out = my_bank[119];
		120: data_out = my_bank[120];
		121: data_out = my_bank[121];
		122: data_out = my_bank[122];
		123: data_out = my_bank[123];
		124: data_out = my_bank[124];
		125: data_out = my_bank[125];
		126: data_out = my_bank[126];
		127: data_out = my_bank[127];
	endcase 
   
end*/


always @ (posedge clk, posedge rst) begin
   if (rst == 1'b1) begin
      for (i=0 ; i< 2**`LOG_N_REGISTERS ; i=i+1) begin
        my_bank[i] <= `DATA_WIDTH'b0;
      end
    end
   else if (wr == 1'b1) begin
      my_bank[address] <= data_in;
   end

end 


endmodule
