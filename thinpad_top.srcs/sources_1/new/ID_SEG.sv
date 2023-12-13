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
    output reg [3:0] error_code,
    output reg [31:0] csr_out,
    output reg [31:0] old_mstatus,
    output reg [31:0] old_sstatus,
    (* DONT_TOUCH = "1" *) input wire [31:0] mstatus_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] mie_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] mtvec_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] mscratch_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] mepc_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] mcause_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] mip_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] satp_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] mhartid_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] mideleg_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] medeleg_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] mtval_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] sstatus_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] sepc_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] scause_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] stval_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] stvec_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] sscratch_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] sie_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] sip_out,
    (* DONT_TOUCH = "1" *) input wire [31:0] time_l,
    (* DONT_TOUCH = "1" *) input wire [31:0] time_h
    );

logic [31:0] instr;
logic [31:0] pc;
logic [6:0] instr_type;
logic [5:0] rs1, rs2;
logic [31:0] a_data_reg;
logic [31:0] b_data_reg;
logic [3:0] error;

assign old_mstatus = mstatus_out;
assign old_sstatus = sstatus_out;

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
                csr_out = 32'b0;
            end
        7'b0010111:                     // AUIPC
            begin
                rs1 = 5'b0;
                rs2 = 5'b0;
                csr_out = 32'b0;
            end
        7'b1101111:                     // JAL
            begin
                rs1 = 5'b0;
                rs2 = 5'b0;
                csr_out = 32'b0;
            end
        7'b1100111:                     // JALR
            begin
                rs1 = instr[19:15];
                rs2 = 5'b0;
                csr_out = 32'b0;
            end
        7'b1100011:                     // BEQ,BNE,BLT,BGE,BLTU,BGEU
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
                csr_out = 32'b0;
            end
        7'b0000011:                     // LB,LW,LH,LBU,LHU
            begin
                rs1 = instr[19:15];
                rs2 = 5'b0;
                csr_out = 32'b0;
            end
        7'b0100011:                     // SB,SW,SH
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
                csr_out = 32'b0;
            end
        7'b0010011:                     // ADDI,ANDI,ORI,SLLI,SRLI,XORI,SRAI,SLTIU,SLTI
            begin
                rs1 = instr[19:15];
                rs2 = 5'b0;
                csr_out = 32'b0;
            end
        7'b0110011:                    // ADD,AND,OR,XOR,MIN,SLTU,SUB,SRA,SRL,SLL,SLT
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
                csr_out = 32'b0;
            end
        7'b1110011:                    // CSRRC,CSRRS,CSRRW,ECALL,EBREAK,MRET
            begin
              if (instr == 32'h10500073) begin  // WFI, treat as illegal for debugging
                rs1 = 5'b0;
                rs2 = 5'b0;
                error = 4'h2;
              end
              else if (instr[14:12] != 3'b000) begin
                rs1 = instr[19:15];
                rs2 = 5'b0;
              end
              else begin
                rs1 = 5'b0;
                rs2 = 5'b0;
              end
              case(instr[31:20])
                12'b0011_0000_0000: csr_out = mstatus_out;
                12'b0011_0000_0100: csr_out = mie_out;
                12'b0011_0000_0101: csr_out = mtvec_out;
                12'b0011_0100_0000: csr_out = mscratch_out;
                12'b0011_0100_0001: csr_out = mepc_out;
                12'b0011_0100_0010: csr_out = mcause_out;
                12'b0011_0100_0100: csr_out = mip_out;
                12'b0001_1000_0000: csr_out = satp_out;
                12'b1111_0001_0100: csr_out = mhartid_out;
                12'b0011_0000_0011: csr_out = mideleg_out;
                12'b0011_0000_0010: csr_out = medeleg_out;
                12'b0011_0100_0011: csr_out = mtval_out;
                12'b0001_0000_0010: csr_out = mstatus_out;
                12'b0001_0000_0000: csr_out = sstatus_out;
                12'b0001_0100_0001: csr_out = sepc_out;
                12'b0001_0100_0010: csr_out = scause_out;
                12'b0001_0100_0011: csr_out = stval_out;
                12'b0001_0000_0101: csr_out = stvec_out;
                12'b0001_0100_0000: csr_out = sscratch_out;
                12'b0001_0000_0100: csr_out = sie_out;
                12'b0001_0100_0100: csr_out = sip_out;
                12'b1100_0000_0001: csr_out = time_l;
                12'b1100_1000_0001: csr_out = time_h;
                default: csr_out = 32'b0;
              endcase
            end
        default: begin
            rs1 = 5'b0;
            rs2 = 5'b0;
            csr_out = 32'b0;
            error = 4'h2;
        end
    endcase
end

always_ff @(posedge clk_i) begin
  if(instr) begin
    if (if_error_code != 4'h0) begin
      error_code <= if_error_code;
    end
    else begin
      if (error != 4'h0) begin
        error_code <= error;
      end
      else begin
        error_code <= 'h0;
        a_data_reg <= rf_rdata_a;
        b_data_reg <= rf_rdata_b;
      end
    end
  end
  else begin
    error_code <= 'h0;
    a_data_reg <= '0;
    b_data_reg <= '0;
  end
end

assign rf_raddr_a = (|instr) ? rs1:0;
assign rf_raddr_b = (|instr) ? rs2:0;
assign pc_out = pc;
assign inst_out = instr;
assign a_out = a_conflict ? a_in : a_data_reg;
assign b_out = b_conflict ? b_in : b_data_reg;

endmodule

/* =================== ID SEG END===============*/