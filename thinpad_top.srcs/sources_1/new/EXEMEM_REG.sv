/* =================== EXEMEM REG =================*/

module REG_EXEMEM(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_in,
    output reg [31:0] pc_out,
    input wire [31:0] inst_in,
    output reg [31:0] inst_out,
    input wire [31:0] alu_in,
    output reg [31:0] alu_out,
    input wire [31:0] b_in,
    output reg [31:0] b_out,
    output reg [5:0] exemem_rd,
    input wire stall_i,
    input wire bubble_i,
    input wire wait_mem_i,
    input wire pc_finish
);

reg [31:0] pc;
reg [31:0] instr;
reg [31:0] alu;
reg [31:0] b;
reg [5:0] rd;

assign pc_out = pc;
assign inst_out = instr;
assign alu_out = alu;
assign b_out = b;
assign exemem_rd = rd;

always_comb begin
  if (inst_in[6:0] != 7'b1100011 && inst_in[6:0] != 7'b0100011) begin
    rd = inst_in[11:7];                                    // not BEQ,SB
  end
  else begin
    rd = 6'b000000;
  end
end

always_ff @(posedge clk_i) begin
  if(rst_i) begin
    pc <= '0;
    instr <= '0;
    alu <= '0;
    b <= '0;
  end
  else if(stall_i || pc_finish || wait_mem_i) begin
  end
  else if(bubble_i) begin
    pc <= '0;
    instr <= '0;
    alu <= '0;
    b <= '0;
  end
  else begin
    pc <= pc_in;
    instr <= inst_in;
    alu <= alu_in;
    b <= b_in;
  end
end

endmodule

/* =================== EXEMEM REG END =================*/
