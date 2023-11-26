/* =================== EXE SEG ===============*/
module SEG_EXE(
    input wire [31:0] inst_in,
    input wire [31:0] pc_in,
    output reg [31:0] pc_out,
    output reg [31:0] inst_out,
    input wire [31:0] rdata_a,
    input wire [31:0] rdata_b,
    output reg [31:0] raddr_out,
    output reg  [31:0] alu_a,
    output reg  [31:0] alu_b,
    output reg  [ 3:0] alu_op,
    input  wire [31:0] alu_y,
    output reg  [31:0] alu_out,
    output reg branch_o,
    output reg [31:0] pc_branch,
    output reg mstatus_we,
    output reg [31:0] mstatus_in,
    input wire [31:0] mstatus_out,
    output reg mie_we,
    output reg [31:0] mie_in,
    input wire [31:0] mie_out,
    output reg mtvec_we,
    output reg [31:0] mtvec_in,
    input wire [31:0] mtvec_out,
    output reg mscratch_we,
    output reg [31:0] mscratch_in,
    input wire [31:0] mscratch_out,
    output reg mepc_we,
    output reg [31:0] mepc_in,
    input wire [31:0] mepc_out,
    output reg mcause_we,
    output reg [31:0] mcause_in,
    input wire [31:0] mcause_out,
    output reg mip_we,
    output reg [31:0] mip_in,
    input wire [31:0] mip_out,
    output reg satp_we,
    output reg [31:0] satp_in,
    input wire [31:0] satp_out
    );

logic [31:0] instr;
logic [31:0] pc;
logic [31:0] a_data_reg;
logic [31:0] b_data_reg;
logic [31:0] alu_reg;
logic [31:0] addr_reg;
logic [6:0] instr_type;
logic [31:0] csr_in;
logic [31:0] csr_out;
logic [1:0] exception_status;   // 00:U, 01:S, 11:M

always_comb begin
    instr = inst_in;
    pc = pc_in;
    a_data_reg = rdata_a;
    b_data_reg = rdata_b;
    instr_type = instr[6:0];
    if(instr_type != 7'b1100011) begin
      branch_o = 1'b0;
    end
    if(instr_type == 7'b1110011)begin
      if(instr[14:12] == 3'b011 || instr[14:12] == 3'b010 || instr[14:12] == 3'b001) begin
        case(instr[14:12])
          3'b011:                      // CSRRC
          begin
            csr_out = csr_in & (~a_data_reg);
            alu_reg = csr_in;
          end
          3'b010:                      // CSRRS
          begin
            csr_out = csr_in | a_data_reg;
            alu_reg = csr_in;
          end
          3'b001:                      // CSRRW
          begin
            csr_out = a_data_reg;
            alu_reg = csr_in;
          end
        endcase
        case(instr[31:20])
          12'b0011_0000_0000:
          begin
            csr_in = mstatus_out;             // 32:mstatus
            mstatus_in = csr_out;
            mstatus_we = 1'b1;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
          end
          12'b0011_0000_0100:
          begin
            csr_in = mie_out;             // 33:mie
            mie_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b1;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
          end
          12'b0011_0000_0101:
          begin
            csr_in = mtvec_out;             // 34:mtvec
            mtvec_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b1;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
          end
          12'b0011_0100_0000:
          begin
            csr_in = mscratch_out;             // 35:mscratch
            mscratch_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b1;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
          end
          12'b0011_0100_0001:
          begin
            csr_in = mepc_out;             // 36:mepc
            mepc_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b1;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
          end
          12'b0011_0100_0010:
          begin
            csr_in = mcause_out;             // 37:mcause
            mcause_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b1;
            mip_we = 1'b0;
            satp_we = 1'b0;
          end
          12'b0011_0100_0100:
          begin
            csr_in = mip_out;             // 38:mip
            mip_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b1;
            satp_we = 1'b0;
          end
          12'b0001_1000_0000:
          begin
            csr_in = satp_out;             // 39:satp
            satp_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b1;
          end
        endcase
      end
      else if(instr == 32'b00110000001000000000000001110011) begin  // MRET
        exception_status = mstatus_out[12:11];
        mstatus_in = 2'b00;

        mstatus_we = 1'b1;
        mie_we = 1'b0;
        mtvec_we = 1'b0;
        mscratch_we = 1'b0;
        mepc_we = 1'b0;
        mcause_we = 1'b0;
        mip_we = 1'b0;
        satp_we = 1'b0;

        pc_branch = mepc_out;
        branch_o = 1'b1;
      end
      else if(instr == 32'b00000000000000000000000001110011) begin  // ECALL
        mstatus_we = 1'b0;
        mie_we = 1'b0;
        mtvec_we = 1'b0;
        mscratch_we = 1'b0;
        mepc_we = 1'b0;
        mcause_we = 1'b1;
        mip_we = 1'b0;
        satp_we = 1'b0;
        case(exception_status)
          2'b00: mcause_in = 8;
          2'b01: mcause_in = 9;
          2'b11: mcause_in = 11;
        endcase

        pc_branch = {2'b00,mtvec_out[31:2]};
        branch_o = 1'b1;
      end
      else if(instr == 32'b00000000000100000000000001110011) begin  // EBREAK
        mstatus_we = 1'b0;
        mie_we = 1'b0;
        mtvec_we = 1'b0;
        mscratch_we = 1'b0;
        mepc_we = 1'b0;
        mcause_we = 1'b1;
        mip_we = 1'b0;
        satp_we = 1'b0;
        mcause_in = 3;

        pc_branch = {2'b00,mtvec_out[31:2]};
        branch_o = 1'b1;
      end
    end
    else begin                           // No CSR registers
      mstatus_we = 1'b0;
      mie_we = 1'b0;
      mtvec_we = 1'b0;
      mscratch_we = 1'b0;
      mepc_we = 1'b0;
      mcause_we = 1'b0;
      mip_we = 1'b0;
      satp_we = 1'b0;
    case(instr_type)
        7'b0110111:                     // LUI
            begin
              alu_reg = instr[31:12] << 12;
            end
        7'b0010111:                     // AUIPC
            begin
              alu_a = pc;
              alu_b = instr[31:12] << 12;
              alu_op = 4'b0001;
              alu_reg = alu_y;
            end
        7'b1101111:                     // JAL
            begin
              alu_reg = pc + 4;
              pc_branch = instr[31] ? pc + {11'b1111_1111_111,instr[31],instr[19:12],instr[20],instr[30:21],1'b0} : pc + {11'b0000_0000_000,instr[31],instr[19:12],instr[20],instr[30:21],1'b0};
              branch_o = 1'b1;
            end
        7'b1100111:                     // JALR
            begin
              alu_reg = pc + 4;
              alu_a = a_data_reg;
              alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:20]} : {20'b0000_0000_0000_0000_0000,instr[31:20]};
              alu_op = 4'b0001;
              pc_branch = alu_y & (~1);
              branch_o = 1'b1;
            end
        7'b1100011:
            begin
              case(instr[14:12])
                3'b000:                 // BEQ
                begin
                  if(a_data_reg == b_data_reg) begin
                      pc_branch = instr[31] ? pc + {19'b1111_1111_1111_1111_111,instr[31],instr[7],instr[30:25],instr[11:8],1'b0} : pc + {19'b0000_0000_0000_0000_000,instr[31],instr[7],instr[30:25],instr[11:8],1'b0};
                      branch_o = 1'b1;
                  end
                  else begin
                      branch_o = 1'b0;
                  end
                end
                3'b001:                 // BNE
                begin
                  if(a_data_reg != b_data_reg) begin
                      pc_branch = instr[31] ? pc + {19'b1111_1111_1111_1111_111,instr[31],instr[7],instr[30:25],instr[11:8],1'b0} : pc + {19'b0000_0000_0000_0000_000,instr[31],instr[7],instr[30:25],instr[11:8],1'b0};
                      branch_o = 1'b1;
                  end
                  else begin
                      branch_o = 1'b0;
                  end
                end
              endcase
            end
        7'b0000011:                     // LB,LW
            begin
              alu_a = a_data_reg;
              alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:20]} : {20'b0000_0000_0000_0000_0000,instr[31:20]};
              alu_op = 4'b0001;
              addr_reg = alu_y;
            end
        7'b0100011:
            begin
              alu_a = a_data_reg;
              alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:25],instr[11:7]} : {20'b0000_0000_0000_0000_0000,instr[31:25],instr[11:7]};
              alu_op = 4'b0001;
              addr_reg = alu_y;
              if(instr[14:12] == 3'b000)     // SB
              begin
                  alu_reg = b_data_reg[7:0];
              end
              else if(instr[14:12] == 3'b010)  // SW
              begin
                  alu_reg = b_data_reg;
              end
            end
        7'b0010011:                         // alu rs1,imm
            begin
            alu_a = a_data_reg;
            alu_reg = alu_y;
            case(instr[14:12])
              3'b000:                       // ADDI
                begin
                  alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:20]} : {20'b0000_0000_0000_0000_0000,instr[31:20]};
                  alu_op = 4'b0001;
                end
              3'b110:                       // ORI
                begin
                  alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:20]} : {20'b0000_0000_0000_0000_0000,instr[31:20]};
                  alu_op = 4'b0100;
                end
              3'b111:                       // ANDI
                begin
                  alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:20]} : {20'b0000_0000_0000_0000_0000,instr[31:20]};
                  alu_op = 4'b0011;
                end
              3'b001:                       // SLLI
                begin
                  alu_b = instr[25] ? 6'b00000 : instr[25:20];
                  alu_op = 4'b0111;
                end
              3'b101:                       // SRLI
                begin
                  alu_b = instr[25] ? 6'b00000 : instr[25:20];
                  alu_op = 4'b1000;
                end
            endcase
            end
        7'b0110011:                             // alu rs1,rs2
            begin
                if (instr[14:12] == 3'b110 && instr[31:25] == 7'b0000000) begin  // OR
                  alu_a = a_data_reg;
                  alu_b = b_data_reg;
                  alu_op = 4'b0100;
                  alu_reg = alu_y;
                end
                if (instr[14:12] == 3'b111 && instr[31:25] == 7'b0000000) begin  // AND
                  alu_a = a_data_reg;
                  alu_b = b_data_reg;
                  alu_op = 4'b0011;
                  alu_reg = alu_y;
                end
                if (instr[14:12] == 3'b100 && instr[31:25] == 7'b0000000) begin  // XOR
                  alu_a = a_data_reg;
                  alu_b = b_data_reg;
                  alu_op = 4'b0101;
                  alu_reg = alu_y;
                end
                if (instr[14:12] == 3'b000 && instr[31:25] == 7'b0000000) begin  // ADD
                  alu_a = a_data_reg;
                  alu_b = b_data_reg;
                  alu_op = 4'b0001;
                  alu_reg = alu_y;
                end
                if (instr[14:12] == 3'b100 && instr[31:25] == 7'b0000101) begin  // MIN
                  alu_a = a_data_reg;
                  alu_b = b_data_reg;
                  if((a_data_reg[31] == 1'b0 && b_data_reg[31] == 1'b0) || (a_data_reg[31] == 1'b1 && b_data_reg[31] == 1'b1)) begin
                    alu_reg = a_data_reg < b_data_reg ? a_data_reg : b_data_reg;
                  end
                  else if(a_data_reg[31] == 1'b1 && b_data_reg[31] == 1'b0) begin
                    alu_reg = a_data_reg;
                  end
                  else begin
                    alu_reg = b_data_reg;
                  end
                end
                if (instr[14:12] == 3'b100 && instr[31:25] == 7'b0100000) begin  // XNOR
                  alu_a = a_data_reg;
                  alu_b = ~b_data_reg;
                  alu_op = 4'b0101;
                  alu_reg = alu_y;
                end
                if (instr[14:12] == 3'b001 && instr[31:25] == 7'b0010100) begin  // SBSET
                  alu_a = a_data_reg;
                  alu_b = 1 << (b_data_reg & 32'b11111);
                  alu_op = 4'b0100;
                  alu_reg = alu_y;
                end
                if(instr[14:12] == 3'b011 && instr[31:25] == 7'b0000000) begin   // SLTU
                  if(a_data_reg[31] == 1'b0 && b_data_reg[31] == 1'b0)
                  begin
                    alu_reg = a_data_reg < b_data_reg;
                  end
                  else if(a_data_reg[31] == 1'b0 && b_data_reg[31] == 1'b1)
                  begin
                    alu_reg = 1'b1;
                  end
                  else if(a_data_reg[31] == 1'b1 && b_data_reg[31] == 1'b0)
                  begin
                    alu_reg = 1'b0;
                  end
                  else
                  begin
                    alu_reg = a_data_reg < b_data_reg;
                  end
                end
            end
    endcase
  end
end

assign pc_out = pc;
assign inst_out = instr;
assign raddr_out = pc ? addr_reg:0;
assign alu_out = pc ? alu_reg:0;

endmodule

/* =================== EXE SEG END===============*/