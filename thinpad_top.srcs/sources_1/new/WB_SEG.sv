/* =================== WB SEG ================*/

module SEG_WB(
    input wire [31:0] data_in,
    input wire [31:0] inst_in,

    output reg  [5:0]  rf_waddr,
    output reg  [31:0] rf_wdata,
    output reg  rf_we
);

logic [31:0] instr;

always_comb begin
instr = inst_in;
if(instr[6:0] != 7'b1100011 && instr[6:0] != 7'b0100011)             // BEQ,BNE,SB,SW
begin
    rf_waddr = instr[11:7];
    rf_wdata = data_in;
    rf_we = 1'b1;
end
else
begin
    rf_we = 1'b0;
end
end

endmodule

/* =================== WB SEG END ===============*/