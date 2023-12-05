/* =================== EXE SEG ===============*/
module SEG_EXE(
  input wire clk_i,
  input wire rst_i,

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
  input wire [31:0] csr_in,
  output reg branch_o,
  output reg [31:0] pc_branch,
  output reg mstatus_we,
  output reg [31:0] mstatus_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] mstatus_out,
  output reg mie_we,
  output reg [31:0] mie_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] mie_out,
  output reg mtvec_we,
  output reg [31:0] mtvec_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] mtvec_out,
  output reg mscratch_we,
  output reg [31:0] mscratch_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] mscratch_out,
  output reg mepc_we,
  output reg [31:0] mepc_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] mepc_out,
  output reg mcause_we,
  output reg [31:0] mcause_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] mcause_out,
  output reg mip_we,
  output reg [31:0] mip_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] mip_out,
  output reg satp_we,
  output reg [31:0] satp_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] satp_out,
  output reg mode_we,
  output reg [1:0] mode_in,
  (* DONT_TOUCH = "1" *) input wire [1:0] mode_out,
  input wire [3:0] id_error_code,
  input wire timeout_i,
  output reg timeout_clear,

  output reg [31:0] wbm2_adr_o,
  input  wire [31:0] wbm2_dat_i,
  output reg wbm2_we_o,
  output reg [3:0] wbm2_sel_o,
  output reg wbm2_stb_o,
  input  wire wbm2_ack_i,
  input  wire wbm2_err_i,
  input  wire wbm2_rty_i,
  output reg wbm2_cyc_o,

  output reg exe_stall,
  output reg req_o,
  output reg [1:0] req_type_o,
  output reg [31:0] va_o,
  input wire [31:0] pa_i,
  input wire ack_i,
  input wire [31:0] pte_addr_i,   // SRAM address, used to read a PTE
  input wire pte_please_i,        // request for a PTE
  output reg [31:0] pte_o,        // PTE from CPU, valid when `pte_ready_i` is '1'
  output reg pte_ready_o,         // '1' means `pte_i` is valid
  input wire [3:0] fault_code_i,  // the same in `exception.h`
  input wire fault_i,             // '1' for fault, '0' for no fault
  input wire [31:0] satp_i,
  input wire [1:0] mode_exe,
  input wire [1:0] mode_reg,
  input wire mode_we_2
  );

logic [31:0] instr;
logic [31:0] pc;
logic [31:0] old_pc;
logic csr_we;
logic [31:0] a_data_reg;
logic [31:0] b_data_reg;
logic [31:0] alu_reg;
logic [31:0] addr_reg;
logic [6:0] instr_type;
logic [31:0] csr_out;
logic [31:0] pp;
logic [3:0] page_error;
logic use_page;
logic exe_finish;

always_ff @(posedge clk_i)begin
if(rst_i)begin
  old_pc <= 32'b0;
  csr_we <= 'b0;
end
else begin
  old_pc <= pc_in;
  if(csr_we == 'b1) begin
    csr_we <= 'b0;
  end
  else if(old_pc != pc) begin
    csr_we <= 'b1;
  end
  else begin
    csr_we <= 'b0;
  end
end
end

typedef enum logic [3:0] {
  STATE_IDLE = 0,
  PAGE_PRE = 1,
  WAIT_PTE_ADDR = 2,
  READ_PTE = 3,
  WAIT_VA = 4,
  STATE_DONE = 5
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
  exe_finish = 1'b0;
  if(rst_i)begin
    nextstate = STATE_IDLE;
  end
  else begin
  case(state)
    STATE_IDLE:begin
      exe_finish = 1'b0;
      if((instr[6:0] == 7'b0000011 || instr[6:0] == 7'b0100011) && pc != old_pc) begin
        if(satp_i[31] == '0 || (mode_we_2 ? mode_exe : mode_reg) == 2'b11) begin
          nextstate = STATE_IDLE;
        end
        else begin
          nextstate = PAGE_PRE;
        end
      end
      else begin
        nextstate = STATE_IDLE;
      end
    end
    PAGE_PRE:begin
      exe_finish = 1'b1;
      nextstate = WAIT_PTE_ADDR;
    end
    WAIT_PTE_ADDR:begin
      exe_finish = 1'b1;
      if(pte_please_i) begin
        nextstate = READ_PTE;
      end
      else begin
        nextstate = WAIT_PTE_ADDR;
      end
    end
    READ_PTE:begin
      exe_finish = 1'b1;
      if(wbm2_ack_i) begin
        nextstate = WAIT_VA;
      end
      else begin
        nextstate = READ_PTE;
      end
    end
    WAIT_VA:begin
      exe_finish = 1'b1;
      if(pte_please_i) begin
        nextstate = READ_PTE;
      end
      else if(ack_i) begin
          nextstate = STATE_DONE;
      end
      else begin
        nextstate = WAIT_VA;
      end
    end
    STATE_DONE:begin
      exe_finish = 1'b1;
      nextstate = STATE_IDLE;
    end
    default: begin
      exe_finish = 1'b0;
      nextstate = STATE_IDLE;
    end
 endcase
end
end

always_ff @(posedge clk_i) begin
  if(rst_i || inst_in == 32'b0)begin
    wbm2_cyc_o <= 1'b0;
    wbm2_stb_o <= 1'b0;
    req_o <= 1'b0;
    pte_ready_o <= 1'b0;
    req_type_o <= 2'b0;
    pte_o <= 32'b0;
    pp <= '0;
    page_error <= '0;
    use_page <= '0;
    va_o <= '0;
    req_type_o <= '0;
  end
  else begin
      case(state)
        STATE_IDLE:begin
          if((instr[6:0] == 7'b0000011 || instr[6:0] == 7'b0100011) && (!(satp_i[31] == '0 || (mode_we_2 ? mode_exe : mode_reg) == 2'b11))) begin
            use_page <= 'b1;
            if(pc != old_pc) begin
              req_o <= 1'b1;
              va_o <= addr_reg;
              if(instr[6:0] == 7'b0000011) begin
                req_type_o <= 2'b01;
              end
              else begin
                req_type_o <= 2'b11;
              end
            end
          end
          else begin
            use_page <= 'b0;
          end
        end
        PAGE_PRE:begin
          req_o <= 1'b0;
        end
        WAIT_PTE_ADDR:begin
          if(pte_please_i) begin
            wbm2_adr_o <= pte_addr_i;
            wbm2_sel_o <= 4'b1111;
            wbm2_cyc_o <= 1'b1;
            wbm2_stb_o <= 1'b1;
            wbm2_we_o <= 1'b0;
          end
        end
        READ_PTE:begin
          if(wbm2_ack_i) begin
            pte_o <= wbm2_dat_i;
            wbm2_cyc_o <= 1'b0;
            wbm2_stb_o <= 1'b0;
            pte_ready_o <= 1'b1;
          end
        end
        WAIT_VA:begin
          pte_ready_o <= 1'b0;
          if(pte_please_i) begin
            wbm2_adr_o <= pte_addr_i;
            wbm2_sel_o <= 4'b1111;
            wbm2_cyc_o <= 1'b1;
            wbm2_stb_o <= 1'b1;
            wbm2_we_o <= 1'b0;
          end
          else if(ack_i) begin
            if(fault_i) begin
              page_error <= fault_code_i;
              pp <= '0;
            end
            else begin
              page_error <= '0;
              pp <= pa_i;
            end
          end
        end
        STATE_DONE:begin
        end
      endcase
   end
end

always_comb begin
  instr = inst_in;
  pc = pc_in;
  a_data_reg = rdata_a;
  b_data_reg = rdata_b;
  instr_type = instr[6:0];
  addr_reg = 'b0;
  alu_a = 'b0;
  alu_b = 'b0;
  alu_op = 'b0;
  alu_reg = 'b0;
  branch_o = 'b0;
  pc_branch = 'b0;
  mstatus_we = 'b0;
  mstatus_in = 'b0;
  mie_we = 'b0;
  mie_in = 'b0;
  mtvec_we = 'b0;
  mtvec_in = 'b0;
  mscratch_we = 'b0;
  mscratch_in = 'b0;
  mepc_we = 'b0;
  mepc_in = 'b0;
  mcause_we = 'b0;
  mcause_in = 'b0;
  mip_we = 'b0;
  mip_in = 'b0;
  satp_we = 'b0;
  satp_in = 'b0;
  mode_we = 'b0;
  mode_in = 2'b11;
  csr_out = 'b0;
  if(instr_type != 7'b1100011) begin
    branch_o = 1'b0;
  end
  if(instr == 32'b0) begin
    timeout_clear = 1'b0;
    mstatus_we = 1'b0;
    mie_we = 1'b0;
    mtvec_we = 1'b0;
    mscratch_we = 1'b0;
    mip_we = 1'b0;
    satp_we = 1'b0;
    mepc_we = 1'b0;
    mcause_we = 1'b0;
    mode_we = 1'b0;
    branch_o = 1'b0;
  end
  else if(timeout_i && mode_out == 2'b00 && instr != 32'b0) begin        // timeout
    timeout_clear = 1'b1;
    mstatus_we = 1'b0;
    mie_we = 1'b0;
    mtvec_we = 1'b0;
    mscratch_we = 1'b0;
    mip_we = 1'b0;
    satp_we = 1'b0;

    mcause_we = csr_we;
    mcause_in = {1'b1,31'b0111};

    mepc_we = csr_we;
    mepc_in = pc;

    mode_we = 1;
    mode_in = 2'b11;

    if(mtvec_out[0] == 'b0)
      pc_branch = {mtvec_out[31:2],2'b00};
    else
      pc_branch = {mtvec_out[31:2],2'b00} + mcause_in << 2 ;
    branch_o = 1'b1;
  end
  else if (!(|id_error_code) && !(|page_error)) begin   // no error / page-fault
    timeout_clear = 1'b0;
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
            // 32:mstatus
            mstatus_in = csr_out;
            mstatus_we = csr_we;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
          end
          12'b0011_0000_0100:
          begin
            // 33:mie
            mie_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = csr_we;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
          end
          12'b0011_0000_0101:
          begin
            // 34:mtvec
            mtvec_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = csr_we;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
          end
          12'b0011_0100_0000:
          begin
            // 35:mscratch
            mscratch_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = csr_we;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
          end
          12'b0011_0100_0001:
          begin
            // 36:mepc
            mepc_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = csr_we;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
          end
          12'b0011_0100_0010:
          begin
            // 37:mcause
            mcause_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = csr_we;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
          end
          12'b0011_0100_0100:
          begin
            // 38:mip
            mip_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = csr_we;
            satp_we = 1'b0;
            mode_we = 1'b0;
          end
          12'b0001_1000_0000:
          begin
            // 39:satp
            satp_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = csr_we;
            mode_we = 1'b0;
          end
          default:begin
          end
        endcase
      end
      else if(instr == 32'b00110000001000000000000001110011) begin  // MRET
        mie_we = 1'b0;
        mtvec_we = 1'b0;
        mscratch_we = 1'b0;
        mepc_we = 1'b0;
        mcause_we = 1'b0;
        mip_we = 1'b0;
        satp_we = 1'b0;
        mstatus_we = 1'b0;

        mode_in = mstatus_out[12:11];
        mode_we = 1'b1;

        pc_branch = mepc_out;
        branch_o = 1'b1;
      end
      else if(instr == 32'b00000000000000000000000001110011) begin  // ECALL
        mstatus_we = 1'b0;
        mie_we = 1'b0;
        mtvec_we = 1'b0;
        mscratch_we = 1'b0;
        mip_we = 1'b0;
        satp_we = 1'b0;

        mcause_we = csr_we;
        case(mode_out)
          2'b00: mcause_in = 8;
          2'b01: mcause_in = 9;
          2'b11: mcause_in = 11;
        endcase

        mepc_we = csr_we;
        mepc_in = pc;

        mode_we = 1'b1;
        mode_in = 2'b11;

        pc_branch = {mtvec_out[31:2],2'b00};
        branch_o = 1'b1;
      end
      else if(instr == 32'b00000000000100000000000001110011) begin  // EBREAK
        mstatus_we = 1'b0;
        mie_we = 1'b0;
        mtvec_we = 1'b0;
        mscratch_we = 1'b0;
        mip_we = 1'b0;
        satp_we = 1'b0;

        mcause_in = 3;
        mcause_we = csr_we;

        mode_we = 1'b1;
        mode_in = 2'b11;

        mepc_we = csr_we;
        mepc_in = pc;

        pc_branch = {mtvec_out[31:2],2'b00};
        branch_o = 1'b1;
      end
      else begin
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
      mode_we = 1'b0;
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
          if (instr[21] == 1'b0) begin
            alu_reg = pc + 4;
            pc_branch = instr[31] ? pc + {11'b1111_1111_111,instr[31],instr[19:12],instr[20],instr[30:21],1'b0} : pc + {11'b0000_0000_000,instr[31],instr[19:12],instr[20],instr[30:21],1'b0};
            branch_o = 1'b1;
          end
          else begin
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;

            mcause_we = csr_we;
            mcause_in = 4'h0;

            mepc_we = csr_we;
            mepc_in = pc;

            mode_we = 1'b1;
            mode_in = 2'b11;

            pc_branch = {mtvec_out[31:2],2'b00};
            branch_o = 1'b1;
          end
        end
        7'b1100111:                     // JALR
        begin
          if (instr[21] == 1'b0) begin
            alu_reg = pc + 4;
            alu_a = a_data_reg;
            alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:20]} : {20'b0000_0000_0000_0000_0000,instr[31:20]};
            alu_op = 4'b0001;
            pc_branch = alu_y & (~1);
            branch_o = 1'b1;
          end 
          else begin
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;

            mcause_we = csr_we;
            mcause_in = 4'h0;

            mepc_we = csr_we;
            mepc_in = pc;

            mode_we = 1'b1;
            mode_in = 2'b11;

            pc_branch = {mtvec_out[31:2],2'b00};
            branch_o = 1'b1;
          end
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
  else begin
    timeout_clear = 1'b0;
    mstatus_we = 1'b0;
    mie_we = 1'b0;
    mtvec_we = 1'b0;
    mscratch_we = 1'b0;
    mip_we = 1'b0;
    satp_we = 1'b0;

    mcause_we = 1'b1;
    mcause_in = use_page ? page_error : id_error_code;

    mepc_we = 1'b1;
    mepc_in = pc;

    mode_we = 1'b1;
    mode_in = 2'b11;

    pc_branch = {mtvec_out[31:2],2'b00};
    branch_o = 1'b1;
  end
end

assign pc_out = pc;
assign inst_out = ((|id_error_code) | (|page_error)) ? 32'b0 : instr;
assign raddr_out = instr ? (use_page ? pp : addr_reg) : 0;
assign alu_out = instr ? alu_reg : 0;
assign exe_stall = exe_finish && !((|id_error_code) | (|page_error));

endmodule

/* =================== EXE SEG END===============*/