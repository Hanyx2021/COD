`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/28 13:59:27
// Design Name: 
// Module Name: trigger
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


module trigger(
    input wire clk,
    input wire push,
    output wire trigger
    );
    
    reg last_push_reg;
    reg trigger_reg;
    always_ff @ (posedge clk)
    begin
        if(trigger_reg || (push && !last_push_reg))
        begin
            trigger_reg <= ~trigger_reg;
        end
        last_push_reg <= push;
    end
    assign trigger = trigger_reg; 
endmodule
