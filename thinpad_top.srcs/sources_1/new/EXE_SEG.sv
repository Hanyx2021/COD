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
  input wire [31:0] old_mstatus,
  input wire [31:0] old_sstatus,
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
  output reg mhartid_we,
  output reg [31:0] mhartid_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] mhartid_out,
  output reg mideleg_we,
  output reg [31:0] mideleg_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] mideleg_out,
  output reg medeleg_we,
  output reg [31:0] medeleg_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] medeleg_out,
  output reg mtval_we,
  output reg [31:0] mtval_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] mtval_out,
  output reg sstatus_we,
  output reg [31:0] sstatus_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] sstatus_out,
  output reg sepc_we,
  output reg [31:0] sepc_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] sepc_out,
  output reg scause_we,
  output reg [31:0] scause_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] scause_out,
  output reg stval_we,
  output reg [31:0] stval_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] stval_out,
  output reg stvec_we,
  output reg [31:0] stvec_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] stvec_out,
  output reg sscratch_we,
  output reg [31:0] sscratch_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] sscratch_out,
  output reg sie_we,
  output reg [31:0] sie_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] sie_out,
  output reg sip_we,
  output reg [31:0] sip_in,
  (* DONT_TOUCH = "1" *) input wire [31:0] sip_out,
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
  output reg [31:0] tlb_flush_addr_o,   // used for SFENCE.VMA
  output reg tlb_flush_o,               // '1' for an SFENCE.VMA instruction
  output reg tlb_flush_all_o,           // '0' for flush entries about `tlb_flush_addr_o`, '1' for all
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
      else if(ack_i) begin
        nextstate = STATE_DONE;
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
          else if(pc != old_pc) begin
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
  mhartid_we = 'b0;
  mhartid_in = 'b0;
  mideleg_we = 'b0;
  mideleg_in = 'b0;
  medeleg_we = 'b0;
  medeleg_in = 'b0;
  mtval_we = 'b0;
  mtval_in = 'b0;
  sstatus_we = 'b0;
  sstatus_in = 'b0;
  sepc_we = 'b0;
  sepc_in = 'b0;
  scause_we = 'b0;
  scause_in = 'b0;
  stval_we = 'b0;
  stval_in = 'b0;
  stvec_we = 'b0;
  stvec_in = 'b0;
  sscratch_we = 'b0;
  sscratch_in = 'b0;
  sie_we = 'b0;
  sie_in = 'b0;
  sip_we = 'b0;
  sip_in = 'b0;
  mode_we = 'b0;
  mode_in = 2'b11;
  csr_out = 'b0;
  if(instr[31:25] == 7'b0001001 && instr[14:0] == 15'b1110011) begin  // set SFENCE.VMA-related output
    tlb_flush_o = 1;
    if(|instr[19:15]) begin
      tlb_flush_addr_o = 32'b0;
      tlb_flush_all_o = 0;
    end
    else begin
      tlb_flush_addr_o = a_data_reg;
      tlb_flush_all_o = 1;
    end
  end
  else begin
    tlb_flush_o = 0;
    tlb_flush_addr_o = 32'b0;
    tlb_flush_all_o = 0;
  end
  if(instr_type != 7'b1100011) begin
    branch_o = 1'b0;
  end
  if(instr == 32'b0) begin                          // bubble
    timeout_clear = 1'b0;
    mstatus_we = 1'b0;
    mie_we = 1'b0;
    mtvec_we = 1'b0;
    mscratch_we = 1'b0;
    mip_we = 1'b0;
    satp_we = 1'b0;
    mepc_we = 1'b0;
    mcause_we = 1'b0;
    mhartid_we = 'b0;
    mideleg_we = 'b0;
    medeleg_we = 'b0;
    mtval_we = 'b0;
    sstatus_we = 'b0;
    sepc_we = 'b0;
    scause_we = 'b0;
    stval_we = 'b0;
    stvec_we = 'b0;
    sscratch_we = 'b0;
    sie_we = 'b0;
    sip_we = 'b0;
    mode_we = 1'b0;
    branch_o = 1'b0;
  end
  else if(timeout_i && mode_out < 2'b11 && instr != 32'b0) begin        // timeout
    timeout_clear = 1'b1;
    mstatus_we = 1'b0;
    mie_we = 1'b0;
    mtvec_we = 1'b0;
    mscratch_we = 1'b0;
    satp_we = 1'b0;
    mhartid_we = 'b0;
    mideleg_we = 'b0;
    medeleg_we = 'b0;
    mtval_we = 'b0;
    sstatus_we = 'b0;
    mepc_we = 'b0;
    mcause_we = 'b0;
    stval_we = 'b0;
    stvec_we = 'b0;
    sscratch_we = 'b0;
    sie_we = 'b0;
    sip_we = 'b0;
    mie_we = 'b0;
    mip_we = 'b0;

    scause_we = csr_we;
    scause_in = {1'b1,31'b0111};

    sepc_we = csr_we;
    sepc_in = pc;

    mode_we = 1;
    mode_in = 2'b01;

    if(stvec_out[0] == 'b0)
      pc_branch = {stvec_out[31:2],2'b00};
    else
      pc_branch = {stvec_out[31:2],2'b00} + scause_in << 2 ;
    branch_o = 1'b1;
  end
  else if (!(|id_error_code) && !(|page_error)) begin   // no error / page-fault
    timeout_clear = 1'b0;
    if(instr_type == 7'b1110011)begin
      if(instr[14:12] != 3'b000 && instr[14:12] != 3'b100) begin
        case(instr[14:12])
          3'b011:                      // CSRRC
          begin
            csr_out = (instr[19:15] == 5'b0) ? csr_in : (csr_in & (~a_data_reg));
            alu_reg = csr_in;
          end
          3'b010:                      // CSRRS
          begin
            csr_out = (instr[19:15] == 5'b0) ? csr_in : (csr_in | a_data_reg);
            alu_reg = csr_in;
          end
          3'b001:                      // CSRRW
          begin
            csr_out = a_data_reg;
            alu_reg = csr_in;
          end
          3'b111:                      // CSRRCI
          begin
            csr_out = (instr[19:15] == 5'b0) ? csr_in : (csr_in & (~{27'b0,instr[19:15]}));
            alu_reg = csr_in;
          end
          3'b110:                      // CSRRSI
          begin
            csr_out = (instr[19:15] == 5'b0) ? csr_in : (csr_in | {27'b0,instr[19:15]});
            alu_reg = csr_in;
          end
          3'b101:                      // CSRRWI
          begin
            csr_out = {27'b0,instr[19:15]};
            alu_reg = csr_in;
          end
        endcase
        case(instr[31:20])
          12'b0011_0000_0000:
          begin
            //mstatus
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
            mhartid_we = 'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0011_0000_0100:
          begin
            //mie
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
            mhartid_we = 'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0011_0000_0101:
          begin
            //mtvec
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
            mhartid_we = 'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0011_0100_0000:
          begin
            //mscratch
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
            mhartid_we = 'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0011_0100_0001:
          begin
            //mepc
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
            mhartid_we = 'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0011_0100_0010:
          begin
            //mcause
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
            mhartid_we = 'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0011_0100_0100:
          begin
            //mip
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
            mhartid_we = 'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0001_1000_0000:
          begin
            //satp
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
            mhartid_we = 'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b1111_0001_0100:
          begin
            //mhartid
            mhartid_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = csr_we;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0011_0000_0011:
          begin
            //mideleg
            mideleg_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = csr_we;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0011_0000_0010:
          begin
            //medeleg
            medeleg_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = 'b0;
            medeleg_we = csr_we;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0011_0100_0011:
          begin
            //mtval
            mtval_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = csr_we;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0001_0000_0000:
          begin
            //sstatus
            sstatus_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = csr_we;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0001_0100_0001:
          begin
            //sepc
            sepc_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = csr_we;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0001_0100_0010:
          begin
            //scause
            scause_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = csr_we;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0001_0100_0011:
          begin
            //stval
            stval_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = csr_we;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0001_0000_0101:
          begin
            //stvec
            stvec_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = csr_we;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0001_0100_0000:
          begin
            //sscratch
            sscratch_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = csr_we;
            sie_we = 'b0;
            sip_we = 'b0;
          end
          12'b0001_0000_0100:
          begin
            //sie
            sie_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = csr_we;
            sip_we = 'b0;
          end
          12'b0001_0100_0100:
          begin
            //sip
            sip_in = csr_out;
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = csr_we;
          end
          default:begin
            mstatus_we = 1'b0;
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mepc_we = 1'b0;
            mcause_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mode_we = 1'b0;
            mhartid_we = 1'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            sstatus_we = 'b0;
            sepc_we = 'b0;
            scause_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;
          end
        endcase
      end
      else if(instr == 32'b0011_0000_0010_0000_0000_0000_0111_0011) begin  // MRET
        mie_we = 1'b0;
        mtvec_we = 1'b0;
        mscratch_we = 1'b0;
        mepc_we = 1'b0;
        mcause_we = 1'b0;
        mip_we = 1'b0;
        satp_we = 1'b0;
        mhartid_we = 'b0;
        mideleg_we = 'b0;
        medeleg_we = 'b0;
        mtval_we = 'b0;
        sstatus_we = 'b0;
        sepc_we = 'b0;
        scause_we = 'b0;
        stval_we = 'b0;
        stvec_we = 'b0;
        sscratch_we = 'b0;
        sie_we = 'b0;
        sip_we = 'b0;

        mstatus_in = {old_mstatus[31:13],2'b00,old_mstatus[10:0]};
        mstatus_we = csr_we;

        mode_in = old_mstatus[12:11];
        mode_we = 1'b1;

        pc_branch = mepc_out;
        branch_o = 1'b1;
      end
      else if(instr == 32'b0001_0000_0010_0000_0000_0000_0111_0011) begin  // SRET
        mie_we = 1'b0;
        mtvec_we = 1'b0;
        mscratch_we = 1'b0;
        mepc_we = 1'b0;
        mcause_we = 1'b0;
        mip_we = 1'b0;
        satp_we = 1'b0;
        mhartid_we = 'b0;
        mideleg_we = 'b0;
        medeleg_we = 'b0;
        mtval_we = 'b0;
        sepc_we = 'b0;
        scause_we = 'b0;
        stval_we = 'b0;
        stvec_we = 'b0;
        sscratch_we = 'b0;
        sie_we = 'b0;
        sip_we = 'b0;

        mstatus_in = {old_mstatus[31:9],1'b0,old_mstatus[7:6],1'b1,old_mstatus[4:2],old_mstatus[5],old_mstatus[0]};
        mstatus_we = 1'b1;

        sstatus_in = {old_sstatus[31:9],1'b0,old_sstatus[7:6],1'b1,old_sstatus[4:2],old_sstatus[5],old_sstatus[0]};
        sstatus_we = 1'b1;

        mode_in = {1'b0,old_sstatus[8]};
        mode_we = 1'b1;

        pc_branch = sepc_out;
        branch_o = 1'b1;
      end
      else if(instr == 32'b0000_0000_0000_0000_0000_0000_0111_0011) begin  // ECALL
        mie_we = 1'b0;
        mtvec_we = 1'b0;
        mscratch_we = 1'b0;
        mip_we = 1'b0;
        satp_we = 1'b0;
        mhartid_we = 'b0;
        mideleg_we = 'b0;
        medeleg_we = 'b0;
        mtval_we = 'b0;
        stval_we = 'b0;
        stvec_we = 'b0;
        sscratch_we = 'b0;
        sie_we = 'b0;
        sip_we = 'b0;

        if(mode_out == 2'b00) begin
          scause_we = csr_we;
          mcause_we = 'b0;
          scause_in = 8;
        end
        else begin
          scause_we = 'b0;
          mcause_we = csr_we;
          case(mode_out)
            2'b01: mcause_in = 9;
            2'b11: mcause_in = 11;
          endcase
        end

        if(mode_out == 2'b00) begin
          sepc_we = csr_we;
          mepc_we = 'b0;
          sepc_in = pc;
        end
        else begin
          sepc_we = 'b0;
          mepc_we = csr_we;
          mepc_in = pc;
        end


        mode_we = 1'b1;
        case(mode_out)
          2'b00:mode_in = 2'b01;
          2'b01:mode_in = 2'b11;
        endcase

        mstatus_we = csr_we;
        case(mode_out)
          2'b00:mstatus_in = {old_mstatus[31:9],1'b0,old_mstatus[7:6],old_mstatus[1],old_mstatus[4:2],1'b0,old_mstatus[0]};
          2'b01:mstatus_in = {old_mstatus[31:13],2'b01,old_mstatus[10:0]};
          2'b11:mstatus_in = {old_mstatus[31:13],2'b11,old_mstatus[10:0]};
        endcase

        if(mode_out == 2'b00) begin
          sstatus_we = csr_we;
          sstatus_in = {old_sstatus[31:9],1'b0,old_sstatus[7:6],old_sstatus[1],old_sstatus[4:2],1'b0,old_sstatus[0]};
        end
        else begin
          sstatus_we = 'b0;
        end

        if(mode_out == 2'b00) begin
          pc_branch = {stvec_out[31:2],2'b00};
        end
        else begin
          pc_branch = {mtvec_out[31:2],2'b00};
        end
        branch_o = 1'b1;
      end
      else if(instr == 32'b00000000000100000000000001110011) begin  // EBREAK
        mie_we = 1'b0;
        mtvec_we = 1'b0;
        mscratch_we = 1'b0;
        mip_we = 1'b0;
        satp_we = 1'b0;
        mhartid_we = 'b0;
        mideleg_we = 'b0;
        medeleg_we = 'b0;
        mtval_we = 'b0;
        stval_we = 'b0;
        stvec_we = 'b0;
        sscratch_we = 'b0;
        sie_we = 'b0;
        sip_we = 'b0;

        if(mode_out == 2'b00) begin
          scause_we = csr_we;
          mcause_we = 'b0;
          scause_in = 3;
        end
        else begin
          scause_we = 'b0;
          mcause_we = csr_we;
          mcause_in = 3;
        end

        if(mode_out == 2'b00) begin
          sepc_we = csr_we;
          mepc_we = 'b0;
          sepc_in = pc;
        end
        else begin
          sepc_we = 'b0;
          mepc_we = csr_we;
          mepc_in = pc;
        end


        mode_we = 1'b1;
        case(mode_out)
          2'b00:mode_in = 2'b01;
          2'b01:mode_in = 2'b11;
        endcase

        mstatus_we = csr_we;
        case(mode_out)
          2'b00:mstatus_in = {old_mstatus[31:9],1'b0,old_mstatus[7:6],old_mstatus[1],old_mstatus[4:2],1'b0,old_mstatus[0]};
          2'b01:mstatus_in = {old_mstatus[31:13],2'b01,old_mstatus[10:0]};
          2'b11:mstatus_in = {old_mstatus[31:13],2'b11,old_mstatus[10:0]};
        endcase

        if(mode_out == 2'b00) begin
          sstatus_we = csr_we;
          sstatus_in = {old_sstatus[31:9],1'b0,old_sstatus[7:6],old_sstatus[1],old_sstatus[4:2],1'b0,old_sstatus[0]};
        end
        else begin
          sstatus_we = 'b0;
        end

        if(mode_out == 2'b00) begin
          pc_branch = {stvec_out[31:2],2'b00};
        end
        else begin
          pc_branch = {mtvec_out[31:2],2'b00};
        end
        branch_o = 1'b1;
      end
      else if(instr[31:25] == 7'b0001001 && instr[14:7] == 8'b0000_0000) begin   // SFENCE.VMA
        mie_we = 1'b0;
        mtvec_we = 1'b0;
        mscratch_we = 1'b0;
        mip_we = 1'b0;
        satp_we = 1'b0;
        mhartid_we = 'b0;
        mideleg_we = 'b0;
        medeleg_we = 'b0;
        mtval_we = 'b0;
        mcause_we = 'b0;
        mepc_we = 'b0;
        mstatus_we = 'b0;
        stval_we = 'b0;
        stvec_we = 'b0;
        sscratch_we = 'b0;
        sie_we = 'b0;
        sip_we = 'b0;
        scause_we = 'b0;
        sepc_we = 'b0;
        sstatus_we = 'b0;

        mode_we = 'b0;

        pc_branch = pc + 4;
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
      mode_we = 1'b0;
      mhartid_we = 'b0;
      mideleg_we = 'b0;
      medeleg_we = 'b0;
      mtval_we = 'b0;
      sstatus_we = 'b0;
      sepc_we = 'b0;
      scause_we = 'b0;
      stval_we = 'b0;
      stvec_we = 'b0;
      sscratch_we = 'b0;
      sie_we = 'b0;
      sip_we = 'b0;
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
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mhartid_we = 'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;

            if(mode_out == 2'b00) begin
              scause_we = csr_we;
              mcause_we = 'b0;
              scause_in = 4'h0;
            end
            else begin
              scause_we = 'b0;
              mcause_we = csr_we;
              mcause_in = 4'h0;
            end

            if(mode_out == 2'b00) begin
              sepc_we = csr_we;
              mepc_we = 'b0;
              sepc_in = pc;
            end
            else begin
              sepc_we = 'b0;
              mepc_we = csr_we;
              mepc_in = pc;
            end

            mode_we = 1'b1;
            case(mode_out)
              2'b00:mode_in = 2'b01;
              2'b01:mode_in = 2'b11;
            endcase

            mstatus_we = csr_we;
            case(mode_out)
              2'b00:mstatus_in = {old_mstatus[31:9],1'b0,old_mstatus[7:6],old_mstatus[1],old_mstatus[4:2],1'b0,old_mstatus[0]};
              2'b01:mstatus_in = {old_mstatus[31:13],2'b01,old_mstatus[10:0]};
              2'b11:mstatus_in = {old_mstatus[31:13],2'b11,old_mstatus[10:0]};
            endcase

            if(mode_out == 2'b00) begin
              sstatus_we = csr_we;
              sstatus_in = {old_sstatus[31:9],1'b0,old_sstatus[7:6],old_sstatus[1],old_sstatus[4:2],1'b0,old_sstatus[0]};
            end
            else begin
              sstatus_we = 'b0;
            end

            if(mode_out == 2'b00) begin
              pc_branch = {stvec_out[31:2],2'b00};
            end
            else begin
              pc_branch = {mtvec_out[31:2],2'b00};
            end
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
            mie_we = 1'b0;
            mtvec_we = 1'b0;
            mscratch_we = 1'b0;
            mip_we = 1'b0;
            satp_we = 1'b0;
            mhartid_we = 'b0;
            mideleg_we = 'b0;
            medeleg_we = 'b0;
            mtval_we = 'b0;
            stval_we = 'b0;
            stvec_we = 'b0;
            sscratch_we = 'b0;
            sie_we = 'b0;
            sip_we = 'b0;

            if(mode_out == 2'b00) begin
              scause_we = csr_we;
              mcause_we = 'b0;
              scause_in = 4'h0;
            end
            else begin
              scause_we = 'b0;
              mcause_we = csr_we;
              mcause_in = 4'h0;
            end

            if(mode_out == 2'b00) begin
              sepc_we = csr_we;
              mepc_we = 'b0;
              sepc_in = pc;
            end
            else begin
              sepc_we = 'b0;
              mepc_we = csr_we;
              mepc_in = pc;
            end

            mode_we = 1'b1;
            case(mode_out)
              2'b00:mode_in = 2'b01;
              2'b01:mode_in = 2'b11;
            endcase

            mstatus_we = csr_we;
            case(mode_out)
              2'b00:mstatus_in = {old_mstatus[31:9],1'b0,old_mstatus[7:6],old_mstatus[1],old_mstatus[4:2],1'b0,old_mstatus[0]};
              2'b01:mstatus_in = {old_mstatus[31:13],2'b01,old_mstatus[10:0]};
              2'b11:mstatus_in = {old_mstatus[31:13],2'b11,old_mstatus[10:0]};
            endcase

            if(mode_out == 2'b00) begin
              sstatus_we = csr_we;
              sstatus_in = {old_sstatus[31:9],1'b0,old_sstatus[7:6],old_sstatus[1],old_sstatus[4:2],1'b0,old_sstatus[0]};
            end
            else begin
              sstatus_we = 'b0;
            end

            if(mode_out == 2'b00) begin
              pc_branch = {stvec_out[31:2],2'b00};
            end
            else begin
              pc_branch = {mtvec_out[31:2],2'b00};
            end
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
  else begin                          // other errors
    timeout_clear = 1'b0;
    mie_we = 1'b0;
    mtvec_we = 1'b0;
    mscratch_we = 1'b0;
    mip_we = 1'b0;
    satp_we = 1'b0;
    mhartid_we = 'b0;
    mideleg_we = 'b0;
    medeleg_we = 'b0;
    mtval_we = 'b0;
    stval_we = 'b0;
    stvec_we = 'b0;
    sscratch_we = 'b0;
    sie_we = 'b0;
    sip_we = 'b0;

    if(mode_out == 2'b00) begin
      mcause_we = 1'b0;
      scause_we = 1'b1;
      scause_in = use_page ? page_error : id_error_code;
    end
    else begin
      scause_we = 1'b0;
      mcause_we = 1'b1;
      mcause_in = use_page ? page_error : id_error_code;
    end


    if(mode_out == 2'b00) begin
      mepc_we = 1'b0;
      sepc_we = 1'b1;
      sepc_in = pc;
    end
    else begin
      sepc_we = 1'b0;
      mepc_we = 1'b1;
      mepc_in = pc;
    end

    mode_we = 1'b1;
    case(mode_out)
      2'b00:mode_in = 2'b01;
      2'b01:mode_in = 2'b11;
    endcase

    mstatus_we = csr_we;
    case(mode_out)
      2'b00:mstatus_in = {old_mstatus[31:9],1'b0,old_mstatus[7:6],old_mstatus[1],old_mstatus[4:2],1'b0,old_mstatus[0]};
      2'b01:mstatus_in = {old_mstatus[31:13],2'b01,old_mstatus[10:0]};
      2'b11:mstatus_in = {old_mstatus[31:13],2'b11,old_mstatus[10:0]};
    endcase

    if(mode_out == 2'b00) begin
      sstatus_we = csr_we;
      sstatus_in = {old_sstatus[31:9],1'b0,old_sstatus[7:6],old_sstatus[1],old_sstatus[4:2],1'b0,old_sstatus[0]};
    end
    else begin
      sstatus_we = 'b0;
      sstatus_in = old_sstatus;
    end


    if(mode_out == 2'b00) begin
      pc_branch = {stvec_out[31:2],2'b00};
    end
    else begin
      pc_branch = {mtvec_out[31:2],2'b00};
    end
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