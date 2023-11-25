/* =================== IF SEG===============*/
module SEG_IF(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_in,            // input PC, may change when jumping
    output reg [31:0] pc_out,           // output PC
    output reg [31:0] inst_out,         // output instruction
    input wire branch_i,                // '1' for read input PC, '0' for PC+4
    input wire stall_i,                 // '0' for update pc_now_reg, '1' for stall
    output reg pc_finish,

    output reg [31:0] wbm0_adr_o,
    output reg [31:0] wbm0_dat_o,
    input  wire [31:0] wbm0_dat_i,
    output reg wbm0_we_o,
    output reg [3:0] wbm0_sel_o,
    output reg wbm0_stb_o,
    input  wire wbm0_ack_i,
    input  wire wbm0_err_i,
    input  wire wbm0_rty_i,
    output reg wbm0_cyc_o
);

logic [31:0] pc_next_reg;
logic [31:0] pc_now_reg;

typedef enum logic [2:0] {
    STATE_IDLE = 0,
    STATE_READ = 1
  } state_t;

state_t state;
state_t nextstate;

always_ff @(posedge clk_i)begin
    if(rst_i)begin
      state <= STATE_IDLE;
    end
    else begin
      state <= nextstate;
    end
end

always_comb begin
    if(rst_i)begin
      nextstate = STATE_IDLE;
    end
    else begin
    case(state)
      STATE_IDLE:begin
        pc_finish = 1'b0;
      if(stall_i) begin
        nextstate = STATE_IDLE;
      end
      else begin
        nextstate = STATE_READ;
      end
      end
      STATE_READ:begin
        pc_finish = 1'b1;
        if(wbm0_ack_i) begin
          nextstate = STATE_IDLE;
        end
        else begin
          nextstate = STATE_READ;
        end
      end
   endcase
  end
end

always_ff @(posedge clk_i) begin
    if(rst_i)begin
      wbm0_cyc_o <= 1'b0;
      wbm0_stb_o <= 1'b0;
      pc_now_reg <= 'h7fff_fffc;
      pc_next_reg <= 'h8000_0000;
    end
    else begin
        if(!stall_i) begin
          if(branch_i) begin
            pc_next_reg <= pc_in;
          end
          else begin
            pc_next_reg <= pc_now_reg + 4;
          end
        end
        case(state)
          STATE_IDLE:begin
            if(!stall_i) begin
              pc_now_reg <= pc_next_reg;
              wbm0_sel_o <= 4'b1111;
              wbm0_cyc_o <= 1'b1;
              wbm0_stb_o <= 1'b1;
              wbm0_we_o <= 1'b0;
            end
          end
          STATE_READ:begin
            if(wbm0_ack_i) begin
              inst_out <= wbm0_dat_i;
              wbm0_cyc_o <= 1'b0;
              wbm0_stb_o <= 1'b0;
              pc_out <= pc_now_reg;
            end
          end
        endcase
     end
end

assign wbm0_adr_o = pc_now_reg;

endmodule

/* =================== IF SEG END =================*/

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
    output reg [31:0] inst_out
    );

logic [31:0] instr;
logic [31:0] pc;
logic [6:0] instr_type;
logic [5:0] rs1, rs2;
logic [31:0] a_data_reg;
logic [31:0] b_data_reg;

always_comb begin
    pc = pc_in;
    instr = inst_in;
    instr_type = instr[6:0];
    case(instr_type)
        7'b0110111:                     // LUI
            begin
            end
        7'b0010111:                     // AUIPC
            begin
            end
        7'b1101111:                     // JAL
            begin
            end
        7'b1100111:                     // JALR
            begin
                rs1 = instr[19:15];
            end
        7'b1100011:                     // BEQ,BNE
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
            end
        7'b0000011:                     // LB,LW
            begin
                rs1 = instr[19:15];
            end
        7'b0100011:                     // SB,SW
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
            end
        7'b0010011:                     // ADDI,ANDI,ORI,SLLI,SRLI
            begin
                rs1 = instr[19:15];
            end
        7'b0110011:                    // ADD,AND,OR,XOR,MIN,SLTU
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
            end
        7'b1110011:                    // CSRRC,CSRRS,CSRRW
            begin
              if (instr[14:12] != 3'b000) begin
                rs1 = instr[19:15];
              end
            end
    endcase
end

always_ff @(posedge clk_i) begin
  if(pc) begin
    a_data_reg <= rf_rdata_a;
    b_data_reg <= rf_rdata_b;
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
    else begin
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

/* =================== MEM SEG ===============*/

module SEG_MEM(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] inst_in,
    input wire [31:0] pc_in,
    input wire [31:0] alu_in,
    input wire [31:0] raddr_in,
    output reg [31:0] data_out,
    output reg [31:0] inst_out,
    output reg [5:0] load_rd,
    output reg data_ack_o,

    output reg [31:0] wbm1_adr_o,
    output reg [31:0] wbm1_dat_o,
    input  wire [31:0] wbm1_dat_i,
    output reg wbm1_we_o,
    output reg [3:0] wbm1_sel_o,
    output reg wbm1_stb_o,
    input  wire wbm1_ack_i,
    input  wire wbm1_err_i,
    input  wire wbm1_rty_i,
    output reg wbm1_cyc_o
    );

logic [31:0] instr;
logic [31:0] pc;
reg [6:0] instr_type;

typedef enum logic [2:0] {
  STATE_IDLE = 0,
  STATE_READ = 1,
  STATE_WRITE = 2,
  STATE_DONE = 3
} state_t;

state_t state;
state_t nextstate;

always_comb begin
    instr_type = inst_in[6:0];
    if(instr[14:12] == 3'b010) begin
      wbm1_sel_o = 4'b1111;                  // LW,SW
    end
    else begin
      if(instr[6:0] == 7'b0000011)                      // LB
      begin
        wbm1_sel_o = 4'b1111;
      end
      else begin
        wbm1_sel_o = 4'b1 << (wbm1_adr_o & 32'h3);     // SB
      end
    end
    if(state == STATE_IDLE) begin
      if(instr_type == 7'b0000011) begin
        load_rd = inst_in[11:7];
      end
      else begin
        load_rd = 6'b000000;
      end
    end
    else begin
      if(instr[6:0] == 7'b0000011) begin
        load_rd = instr[11:7];
      end
      else begin
        load_rd = 6'b000000;
      end
    end
end

always_ff @(posedge clk_i)begin
    if(rst_i)begin
      state <= STATE_IDLE;
    end
    else begin
      state <= nextstate;
    end
  end

always_comb begin
    if(rst_i)begin
      nextstate = STATE_IDLE;
    end
    else begin
    case(state)
      STATE_IDLE:begin
        if(instr_type == 7'b0000011)begin          // LB,LW
          nextstate = STATE_READ;
        end
        else if(instr_type == 7'b0100011) begin    // SW,SB
          nextstate = STATE_WRITE;
        end
        else begin                                 // no need to read or write
          nextstate = STATE_IDLE;
        end
      end
      STATE_READ:begin
        if(wbm1_ack_i) begin
          nextstate = STATE_DONE;
        end
        else begin
          nextstate = STATE_READ;
        end
      end
      STATE_WRITE:begin
        if(wbm1_ack_i) begin
          nextstate = STATE_DONE;
        end
        else begin
          nextstate = STATE_WRITE;
        end
      end
      STATE_DONE:begin
          nextstate = STATE_IDLE;
      end
   endcase
  end
  end

  always_ff @(posedge clk_i)begin
    if(rst_i)begin
      wbm1_cyc_o <= 1'b0;
      wbm1_stb_o <= 1'b0;
      wbm1_we_o <= 1'b1;
      data_ack_o <= 1'b0;
    end
    else begin
      case(state)
        STATE_IDLE:begin
          pc <= pc_in;
          instr <= inst_in;
          if(instr_type == 7'b0100011) begin             // SB,SW
            wbm1_cyc_o <= 1'b1;
            wbm1_stb_o <= 1'b1;
            wbm1_we_o <= 1'b1;
            wbm1_adr_o <= raddr_in;
            wbm1_dat_o <= alu_in;
            data_ack_o <= 1'b1;
          end
          else if(instr_type == 7'b0000011) begin        // LB
            wbm1_cyc_o <= 1'b1;
            wbm1_stb_o <= 1'b1;
            wbm1_we_o <= 1'b0;
            wbm1_adr_o <= raddr_in;
            data_ack_o <= 1'b1;
          end
          else begin                              // no need to read or write
            data_out <= alu_in;
            data_ack_o <= 1'b0;
          end
        end
        STATE_READ:begin
          if(wbm1_ack_i) begin                      // LB,LW
            if(instr[14:12] == 3'b010) begin
              data_out <= wbm1_dat_i;
            end
            else begin
              case(wbm1_adr_o[1:0])
                  2'b00: data_out <= {24'b0,wbm1_dat_i[7:0]};
                  2'b01: data_out <= {24'b0,wbm1_dat_i[15:8]};
                  2'b10: data_out <= {24'b0,wbm1_dat_i[23:16]};
                  2'b11: data_out <= {24'b0,wbm1_dat_i[31:24]};
              endcase
            end
            wbm1_cyc_o <= 1'b0;
            wbm1_stb_o <= 1'b0;
            data_ack_o <= 1'b0;
            wbm1_we_o <= 1'b1;
          end
        end
        STATE_WRITE:begin                          // SW,SB
          if(wbm1_ack_i) begin
            wbm1_cyc_o <= 1'b0;
            wbm1_stb_o <= 1'b0;
            data_ack_o <= 1'b0;
            wbm1_we_o <= 1'b1;
          end
        end
      endcase
    end
  end

assign inst_out = instr;

endmodule

/* =================== MEM SEG END =================*/

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
    input wire pc_finish
);

reg [31:0] pc;
reg [31:0] instr;
reg [31:0] a;
reg [31:0] b;
reg [5:0] rs1;
reg [5:0] rs2;
reg [5:0] load_rd;

assign pc_out = pc;
assign inst_out = instr;
assign a_out = a;
assign b_out = b;
assign idexe_rs1 = rs1;
assign idexe_rs2 = rs2;

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
  end
  else if(stall_i || pc_finish) begin
  end
  else if(bubble_i || ((load_rd != '0 && (load_rd == rs1 || load_rd == rs2)) || (load_rd2 != '0 && (load_rd2 == rs1 || load_rd2 == rs2)))) begin
    pc <= '0;
    instr <= '0;
    a <= '0;
    b <= '0;
  end
  else begin
    pc <= pc_in;
    instr <= inst_in;
    a <= a_in;
    b <= b_in;
  end
end

endmodule

/* =================== IDEXE REG END =================*/

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
  else if(stall_i || pc_finish) begin
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

/*==================== ID confict ================*/
module ID_confict(                           // for DATA FORWARDING
  input wire  [5:0]  idexe_rs1,              // register rs1 for stage EXE
  input wire  [5:0]  idexe_rs2,              // register rs2 for stage EXE
  input wire  [5:0]  exemem_rd,              // the dest register of instruction LOAD to be used at stage MEM
  input wire  [5:0]  memwb_rd,               // the register to which rd writes back at stage WB
  output reg  conflict_rs1,
  output reg  conflict_rs2,
  output reg [31:0] rs1_out,
  output reg [31:0] rs2_out,
  input wire [31:0] exemem_in,
  input wire [31:0] memwb_in
  );

always_comb begin
    if((exemem_rd != 0 && exemem_rd == idexe_rs1) || (memwb_rd != 0 && memwb_rd == idexe_rs1)) begin
        conflict_rs1 = 1'b1;
        if(exemem_rd != 0 && exemem_rd == idexe_rs1) begin
          rs1_out = exemem_in;
        end
        else begin
          rs1_out = memwb_in;
        end
    end
    else begin
      conflict_rs1 = 1'b0;
    end

    if((exemem_rd != 0 && exemem_rd == idexe_rs2) || (memwb_rd != 0 && memwb_rd == idexe_rs2)) begin
        conflict_rs2 = 1'b1;
        if(exemem_rd != 0 && exemem_rd == idexe_rs2) begin
          rs2_out = exemem_in;
        end
        else begin
          rs2_out = memwb_in;
        end
    end
    else begin
      conflict_rs2 = 1'b0;
    end
end

endmodule
/*==================== ID confict END ================*/

/*==================== Confict Controller ================*/
module conflict_controller(
  input wire branch_conflict_i,
  input wire data_ack_i,
  input wire pc_stall_i,
  output reg pc_ack_o,
  output reg ifid_stall_o,
  output reg ifid_bubble_o,
  output reg idexe_stall_o,
  output reg idexe_bubble_o,
  output reg exemem_stall_o,
  output reg exemem_bubble_o,
  output reg memwb_stall_o,
  output reg memwb_bubble_o
  );

always_comb begin
  exemem_bubble_o = '0;
  memwb_bubble_o = '0;
  memwb_stall_o = '0;
  if(branch_conflict_i) begin
    ifid_bubble_o = '1;
    ifid_stall_o = '0;
  end
  else if(data_ack_i || pc_stall_i) begin
    ifid_bubble_o = '0;
    ifid_stall_o = '1;
  end
  else begin
    ifid_bubble_o = '0;
    ifid_stall_o = '0;
  end
  if(branch_conflict_i) begin
    idexe_bubble_o = '1;
  end
  else begin
    idexe_bubble_o = '0;
  end
  if(data_ack_i) begin
    idexe_stall_o = '1;
    exemem_stall_o = '1;
    memwb_stall_o = '1;
  end
  else begin
    idexe_stall_o = '0;
    exemem_stall_o = '0;
  end
  if(data_ack_i || pc_stall_i) begin
    pc_ack_o = '1;
  end
  else begin
    pc_ack_o = '0;
  end
end
endmodule
/*==================== Confict Controller END================*/
