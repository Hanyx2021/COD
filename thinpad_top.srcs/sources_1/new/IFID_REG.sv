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
    input wire pc_finish,
    input wire timeout_clear_i,
    output reg timeout_clear_o,

    input wire [3:0] if_error_code,
    output reg [3:0] id_error_code
);

reg [31:0] pc;
reg [31:0] instr;
reg [3:0] error_code;

assign pc_out = pc;
assign inst_out = instr;
assign id_error_code = error_code;
assign timeout_clear_o = timeout_clear_i && !(stall_i || pc_finish);

always_ff @(posedge clk_i) begin
  if(rst_i) begin
    pc <= '0;
    instr <= '0;
    error_code <= '0;
  end
  else if(stall_i || pc_finish) begin
  end
  else if(bubble_i) begin
    pc <= '0;
    instr <= '0;
    error_code <= '0;
  end
  else begin
    pc <= pc_in;
    instr <= inst_in;
    error_code <= if_error_code;
  end
end

endmodule

/* =================== IFID REG END ===============*/