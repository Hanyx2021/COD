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
    input wire[5:0] waddr,
    input wire[31:0] wdata,
    input wire we,
    input wire[5:0] raddr_a,
    output reg[31:0] rdata_a,
    input wire[5:0] raddr_b,
    output reg[31:0] rdata_b
    );
    reg [31:0] data_reg [0:31];
    integer i;

    always_ff @ (posedge clk or posedge reset) begin
        if(reset) begin
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

module CSR_reg(
    input wire clk,
    input wire reset,

    input wire we,
    input wire[31:0] data_in,
    output reg[31:0] data_out
);

reg [31:0] data;

always_ff @ (posedge clk or posedge reset) begin

    if(reset) begin
        data <= 32'b0;
    end
    else begin
        if(we) begin
            data <= data_in;
        end
    end
end

assign data_out = data;

endmodule

module MODE_reg(
    input wire clk,
    input wire reset,

    input wire we,
    input wire[1:0] data_in,
    output reg[1:0] data_out
);

reg [1:0] data;

always_ff @ (posedge clk or posedge reset) begin

    if(reset) begin
        data <= 2'b11;
    end
    else begin
        if(we) begin
            data <= data_in;
        end
    end
end

assign data_out = data;

endmodule
