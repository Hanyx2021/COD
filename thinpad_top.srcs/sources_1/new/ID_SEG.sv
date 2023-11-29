/* =================== ID SEG ===============*/
module SEG_ID(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] inst_in,
    input wire [31:0] pc_in,
    output wire [31:0] pc_out,
    output reg  [5:0]  rf_raddr_a,
    input  wire [31:0] rf_rdata_a,
    output reg  [5:0]  rf_raddr_b,
    input  wire [31:0] rf_rdata_b,
    input wire a_conflict,
    input wire b_conflict,
    input wire [31:0] a_in,
    input wire [31:0] b_in,
    output reg [31:0] a_out,
    output reg [31:0] b_out,
    output reg [31:0] inst_out,
    input wire [3:0] if_error_code,
    output reg [3:0] error_code
    );

logic [31:0] instr;
logic [31:0] pc;
logic [6:0] instr_type;
logic [5:0] rs1, rs2;
logic [31:0] a_data_reg;
logic [31:0] b_data_reg;
logic [3:0] error;

always_comb begin
    pc = pc_in;
    instr = inst_in;
    instr_type = instr[6:0];
    error = 4'h0;
    case(instr_type)
        7'b0110111:                     // LUI
            begin
                rs1 = 5'b0;
                rs2 = 5'b0;
            end
        7'b0010111:                     // AUIPC
            begin
                rs1 = 5'b0;
                rs2 = 5'b0;
            end
        7'b1101111:                     // JAL
            begin
                rs1 = 5'b0;
                rs2 = 5'b0;
            end
        7'b1100111:                     // JALR
            begin
                rs1 = instr[19:15];
                rs2 = 5'b0;
            end
        7'b1100011:                     // BEQ,BNE
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
            end
        7'b0000011:                     // LB,LW
            begin
                rs1 = instr[19:15];
                rs2 = 5'b0;
            end
        7'b0100011:                     // SB,SW
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
            end
        7'b0010011:                     // ADDI,ANDI,ORI,SLLI,SRLI
            begin
                rs1 = instr[19:15];
                rs2 = 5'b0;
            end
        7'b0110011:                    // ADD,AND,OR,XOR,MIN,SLTU
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
            end
        7'b1110011:                    // CSRRC,CSRRS,CSRRW,ECALL,EBREAK,MRET
            begin
              if (instr[14:12] != 3'b000) begin
                rs1 = instr[19:15];
                rs2 = 5'b0;
              end
              else begin
                rs1 = 5'b0;
                rs2 = 5'b0;
              end
            end
        default: begin
            rs1 = 5'b0;
            rs2 = 5'b0;
            error = 4'h2;
        end
    endcase
end

always_ff @(posedge clk_i) begin
  if(pc) begin
    if (if_error_code != 4'h0) begin
      error_code <= if_error_code;
    end
    else begin
      if (error != 4'h0) begin
        error_code <= error;
      end
      else begin
        a_data_reg <= rf_rdata_a;
        b_data_reg <= rf_rdata_b;
      end
  end
  else begin
    a_data_reg <= '0;
    b_data_reg <= '0;
  end
end

assign rf_raddr_a = pc ? rs1:0;
assign rf_raddr_b = pc ? rs2:0;
assign pc_out = pc;
assign inst_out = instr;
assign a_out = a_conflict ? a_in : a_data_reg;
assign b_out = b_conflict ? b_in : b_data_reg;

endmodule

/* =================== ID SEG END===============*/