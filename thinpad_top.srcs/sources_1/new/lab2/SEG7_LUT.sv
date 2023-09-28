`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/28 14:47:02
// Design Name: 
// Module Name: SEG7_LUT
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


module SEG7_LUT_2(
    input wire[3:0] count,
    output wire[7:0] digit
    );

  reg [6:0] oSEG;

  always_comb begin
    case (count)
      4'h1: oSEG = 7'b1110110;  // ---t----
      4'h2: oSEG = 7'b0100001;  // |      |
      4'h3: oSEG = 7'b0100100;  // lt    rt
      4'h4: oSEG = 7'b0010110;  // |      |
      4'h5: oSEG = 7'b0001100;  // ---m----
      4'h6: oSEG = 7'b0001000;  // |      |
      4'h7: oSEG = 7'b1100110;  // lb    rb
      4'h8: oSEG = 7'b0000000;  // |      |
      4'h9: oSEG = 7'b0000110;  // ---b----
      4'ha: oSEG = 7'b0000010;
      4'hb: oSEG = 7'b0011000;
      4'hc: oSEG = 7'b1001001;
      4'hd: oSEG = 7'b0110000;
      4'he: oSEG = 7'b0001001;
      4'hf: oSEG = 7'b0001011;
      4'h0: oSEG = 7'b1000000;
    endcase
  end
  assign digit = {~oSEG, 1'b0};
endmodule
