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
    // 33:mie
    // 34:mtvec
    // 35:mscratch
    // 36:mepc
    // 37:mcause
    // 38:mip
    reg [31:0] data_reg [0:38];
    reg a_reg;
    reg b_reg;
    integer i;
    
    always_ff @ (posedge clk or posedge reset) begin
        if(reset) begin
            a_reg <= 'b0;
            b_reg <= 'b0;
            for(i = 0 ;i < 39;i++)begin 
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

module csr_converter(
    input wire [11:0] csrindex,
    output wire [5:0] csrreg
);

always_comb begin
    case(csrindex)
        12'b0011_0000_0000:
            begin
                csrreg = 6'b100000;             // 32:mstatus
            end
        12'b0011_0000_0100:
            begin
                csrreg = 6'b100001;             // 33:mie
            end
        12'b0011_0000_0101:
            begin
                csrreg = 6'b100010;             // 34:mtvec
            end
        12'b0011_0100_0000:
            begin
                csrreg = 6'b100011;             // 35:mscratch
            end
        12'b0011_0100_0001:
            begin
                csrreg = 6'b100100;             // 36:mepc
            end
        12'b0011_0100_0010:
            begin
                csrreg = 6'b100101;             // 37:mcause
            end
        12'b0011_0100_0100:
            begin
                csrreg = 6'b100110;             // 38:mip
            end
    endcase
end

endmodule
