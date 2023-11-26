/* =================== IFID REG ===============*/

module REG_IFID(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_in,
    output reg [31:0] pc_out,
    input wire [31:0] inst_in,
    output reg [31:0] inst_out,
    input wire stall_i,
    input wire bubble_i,
    input wire pc_finish
);

reg [31:0] pc;
reg [31:0] instr;

assign pc_out = pc;
assign inst_out = instr;


always_ff @(posedge clk_i) begin
  if(rst_i) begin
    pc <= '0;
    instr <= '0;
  end
  else if(stall_i || pc_finish) begin
  end
  else if(bubble_i) begin
    pc <= '0;
    instr <= '0;
  end
  else begin
    pc <= pc_in;
    instr <= inst_in;
  end
end

endmodule

/* =================== IFID REG END ===============*/