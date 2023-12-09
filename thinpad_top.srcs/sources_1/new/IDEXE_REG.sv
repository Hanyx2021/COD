/* =================== IDEXE REG ===============*/

module REG_IDEXE(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_in,
    output reg [31:0] pc_out,
    input wire [31:0] inst_in,
    output reg [31:0] inst_out,
    input wire [31:0] a_in,
    output reg [31:0] a_out,
    input wire [31:0] b_in,
    output reg [31:0] b_out,
    input wire [5:0] load_rd2,
    output reg [5:0] idexe_rs1,
    output reg [5:0] idexe_rs2,
    output reg if_stall_o,
    input wire stall_i,
    input wire bubble_i,
    input wire pc_finish,
    input wire [31:0] csr_in,
    output wire [31:0] csr_out,
    input wire [31:0] mstatus_in,
    output reg [31:0] mstatus_out,
    input wire [31:0] sstatus_in,
    output reg [31:0] sstatus_out,

    input wire [3:0] id_error_code,
    output wire [3:0] exe_error_code
);

reg [31:0] pc;
reg [31:0] instr;
reg [31:0] a;
reg [31:0] b;
reg [5:0] rs1;
reg [5:0] rs2;
reg [5:0] load_rd;
reg [3:0] error_code;
reg [31:0] csr;
reg [31:0] mstatus;
reg [31:0] sstatus;

assign pc_out = pc;
assign inst_out = instr;
assign a_out = a;
assign b_out = b;
assign idexe_rs1 = rs1;
assign idexe_rs2 = rs2;
assign exe_error_code = error_code;
assign csr_out = csr;
assign mstatus_out = mstatus;
assign sstatus_out = sstatus;

always_comb begin
  if (inst_in[6:0] != 7'b0110111 && inst_in[6:0] != 7'b0010111 && inst_in[6:0] != 7'b1101111) begin
    rs1 = inst_in[19:15];                         // not LUI,AUIPC,JAL
  end
  else begin
    rs1 = 6'b000000;
  end
  if (inst_in[6:0] == 7'b1100011 || inst_in[6:0] == 7'b0100011 || inst_in[6:0] == 7'b0110011) begin
    rs2 = inst_in[24:20];                         // BEQ,SB,ADD
  end
  else begin
    rs2 = 6'b000000;
  end
  if(instr[6:0] == 7'b0000011) begin              // LB,LW
    load_rd = instr[11:7];
  end
  else begin
    load_rd = 6'b000000;
  end
  if ((load_rd != '0 && (load_rd == rs1 || load_rd == rs2)) || (load_rd2 != '0 && (load_rd2 == rs1 || load_rd2 == rs2))) begin
    if_stall_o = 'b1;
  end
  else begin
    if_stall_o = 'b0;
  end
end

always_ff @(posedge clk_i) begin
  if(rst_i) begin
    pc <= '0;
    instr <= '0;
    a <= '0;
    b <= '0;
    error_code <= '0;
    csr <= '0;
    mstatus <= '0;
    sstatus <= '0;
  end
  else if(stall_i || pc_finish) begin
  end
  else if(bubble_i || ((load_rd != '0 && (load_rd == rs1 || load_rd == rs2)) || (load_rd2 != '0 && (load_rd2 == rs1 || load_rd2 == rs2)))) begin
    pc <= '0;
    instr <= '0;
    a <= '0;
    b <= '0;
    error_code <= '0;
    csr <= '0;
    mstatus <= '0;
    sstatus <= '0;
  end
  else begin
    pc <= pc_in;
    instr <= inst_in;
    a <= a_in;
    b <= b_in;
    error_code <= id_error_code;
    csr <= csr_in;
    mstatus <= mstatus_in;
    sstatus <= sstatus_in;
  end
end

endmodule

/* =================== IDEXE REG END =================*/