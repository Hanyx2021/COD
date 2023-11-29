`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/13 20:40:20
// Design Name: 
// Module Name: ALU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ALU(
    input wire[3:0] op,
    input wire signed[31:0] rs1,
    input wire signed[31:0] rs2,
    output reg signed[31:0] rd
    );
    
    logic times;
    
    always_comb begin
        case(op) 
            4'b0001:rd = rs1 + rs2;
            4'b0010:rd = rs1 - rs2;
            4'b0011:rd = rs1 & rs2;
            4'b0100:rd = rs1 | rs2;
            4'b0101:rd = rs1 ^ rs2;
            4'b0110:rd = ~rs1;
            4'b0111:rd = rs1 << rs2[5:0];
            4'b1000:rd = rs1 >> rs2[5:0];
            4'b1001:rd = rs1 >>> rs2[5:0];
            4'b1010:rd = (rs1 >> (32 - rs2[5:0])) | (rs1 << rs2[5:0]);
            default:rd = 32'b0;
        endcase
    end
  
endmodule
