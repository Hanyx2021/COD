`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/13 21:02:43
// Design Name: 
// Module Name: register
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


module register(
    input wire clk,
    input wire reset,
    input wire[4:0] waddr,
    input wire[31:0] wdata,
    input wire we,
    input wire[4:0] raddr_a,
    output reg[31:0] rdata_a,
    input wire[4:0] raddr_b,
    output reg[31:0] rdata_b
    );
    
    reg [31:0] data_reg [0:31];
    reg a_reg;
    reg b_reg;
    integer i;
    
    always_ff @ (posedge clk or posedge reset) begin
        if(reset) begin
            a_reg <= 'b0;
            b_reg <= 'b0;
            for(i = 0 ;i < 32;i++)begin 
                data_reg[i] <= 'b0;
            end
        end
        else begin
            if(we) begin
                if(waddr != 'b0) begin
                    data_reg[waddr] <= wdata;
                end
            end
        end
    end
    assign    rdata_a = data_reg[raddr_a];
    assign    rdata_b = data_reg[raddr_b];
endmodule
