/* =================== MEMWB REG =================*/

module REG_MEMWB(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] data_in,
    output reg [31:0] data_out,
    input wire [31:0] inst_in,
    output reg [31:0] inst_out,
    output reg [5:0] memwb_rd,
    input wire stall_i,
    input wire bubble_i,
    input wire pc_finish
);

reg [31:0] data;
reg [31:0] instr;
reg [5:0] rd;

assign data_out = data;
assign inst_out = instr;
assign memwb_rd = rd;

always_comb begin
  if (inst_in[6:0] != 7'b1100011 && inst_in[6:0] != 7'b0100011) begin
    rd = inst_in[11:7];                                 // not BEQ,SB
  end
  else begin
    rd = 6'b000000;
  end
end

always_ff @(posedge clk_i) begin
  if(rst_i) begin
    data <= '0;
    instr <= '0;
  end
  else if(stall_i || pc_finish) begin
  end
  else if(bubble_i) begin
    data <= '0;
    instr <= '0;
  end
  else begin
    data <= data_in;
    instr <= inst_in;
  end
end

endmodule

/* =================== MEMWB REG END =================*/