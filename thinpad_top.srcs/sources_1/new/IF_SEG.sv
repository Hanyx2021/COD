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
  input wire exe_finish_i,            // '1' for EXE not finished yet
  input wire tlb_flush_i,             // '1' for TLB is being flushed

  output reg [31:0] wbm0_adr_o,
  input  wire [31:0] wbm0_dat_i,
  output reg wbm0_we_o,
  output reg [3:0] wbm0_sel_o,
  output reg wbm0_stb_o,
  input  wire wbm0_ack_i,
  input  wire wbm0_err_i,
  input  wire wbm0_rty_i,
  output reg wbm0_cyc_o,
  output reg [3:0] error_code,

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
  input wire mode_we

);

logic [31:0] pc_next_reg;
logic [31:0] pc_now_reg;
logic [3:0] error;

typedef enum logic [3:0] {
  STATE_IDLE = 0,
  PAGE_PRE = 1,
  WAIT_PTE_ADDR = 2,
  READ_PTE = 3,
  WAIT_VA = 4,
  ERROR_PRO = 5,
  STATE_READ = 6,
  WAIT_FAULT = 7
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
  pc_finish = 1'b0;
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
        if(satp_i[31] == '0 || (mode_we ? mode_exe : mode_reg) == 2'b11) begin
          nextstate = STATE_READ;
        end
        else begin
          nextstate = PAGE_PRE;
        end
      end
    end
    PAGE_PRE:begin
      pc_finish = 1'b1;
      nextstate = tlb_flush_i ? (exe_finish_i ? WAIT_FAULT : STATE_IDLE) : WAIT_PTE_ADDR;
    end
    WAIT_PTE_ADDR:begin
      pc_finish = 1'b1;
      if(pte_please_i) begin
        nextstate = READ_PTE;
      end
      else if(ack_i) begin
        if(fault_i) begin
          nextstate = ERROR_PRO;
        end
        else begin
          nextstate = STATE_READ;
        end
      end
      else begin
        nextstate = WAIT_PTE_ADDR;
      end
    end
    READ_PTE:begin
      pc_finish = 1'b1;
      if(wbm0_ack_i) begin
        nextstate = WAIT_VA;
      end
      else begin
        nextstate = READ_PTE;
      end
    end
    WAIT_VA:begin
      pc_finish = 1'b1;
      if(pte_please_i) begin
        nextstate = READ_PTE;
      end
      else if(ack_i) begin
        if(fault_i) begin
          nextstate = ERROR_PRO;
        end
        else begin
          nextstate = STATE_READ;
        end
      end
      else begin
        nextstate = WAIT_VA;
      end
    end
    ERROR_PRO:begin
      pc_finish = 1'b1;
      nextstate = exe_finish_i ? WAIT_FAULT : STATE_IDLE;
    end
    STATE_READ:begin
      pc_finish = 1'b1;
      if(wbm0_ack_i) begin
        nextstate = exe_finish_i ? WAIT_FAULT : STATE_IDLE;
      end
      else begin
        nextstate = STATE_READ;
      end
    end
    WAIT_FAULT: begin
      pc_finish = 1'b1;
      nextstate = exe_finish_i ? WAIT_FAULT : STATE_IDLE;
    end
    default: begin
      pc_finish = 1'b0;
      nextstate = STATE_IDLE;
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
    error <= 4'b0;
    req_o <= 1'b0;
    pte_ready_o <= 1'b0;
    req_type_o <= 2'b0;
    pte_o <= 32'b0;
  end
  else begin
      if(branch_i) begin
        pc_next_reg <= pc_in;
      end
      else begin
        pc_next_reg <= pc_now_reg + 4;
      end
      case(state)
        STATE_IDLE:begin
          if(!stall_i) begin
            pc_now_reg <= pc_next_reg;
            error <= 4'b0;
            if(!(satp_i[31] == '0 || (mode_we ? mode_exe : mode_reg) == 2'b11)) begin
              req_o <= 1'b1;
            end
            else begin
              req_o <= 1'b0;
              wbm0_adr_o <= pc_next_reg;
              wbm0_sel_o <= 4'b1111;
              wbm0_cyc_o <= 1'b1;
              wbm0_stb_o <= 1'b1;
              wbm0_we_o <= 1'b0;
            end
          end
        end
        PAGE_PRE:begin
          req_o <= 1'b0;
        end
        WAIT_PTE_ADDR:begin
          if(pte_please_i) begin
            wbm0_adr_o <= pte_addr_i;
            wbm0_sel_o <= 4'b1111;
            wbm0_cyc_o <= 1'b1;
            wbm0_stb_o <= 1'b1;
            wbm0_we_o <= 1'b0;
          end
          else if(ack_i) begin
            if(fault_i) begin
              error <= fault_code_i;
            end
            else begin
              wbm0_adr_o <= pa_i;
              wbm0_sel_o <= 4'b1111;
              wbm0_cyc_o <= 1'b1;
              wbm0_stb_o <= 1'b1;
              wbm0_we_o <= 1'b0;
            end
          end
        end
        READ_PTE:begin
          if(wbm0_ack_i) begin
            pte_o <= wbm0_dat_i;
            wbm0_cyc_o <= 1'b0;
            wbm0_stb_o <= 1'b0;
            pte_ready_o <= 1'b1;
          end
        end
        WAIT_VA:begin
          pte_ready_o <= 1'b0;
          if(pte_please_i) begin
            wbm0_adr_o <= pte_addr_i;
            wbm0_sel_o <= 4'b1111;
            wbm0_cyc_o <= 1'b1;
            wbm0_stb_o <= 1'b1;
            wbm0_we_o <= 1'b0;
          end
          else if(ack_i) begin
            if(fault_i) begin
              error <= fault_code_i;
            end
            else begin
              wbm0_adr_o <= pa_i;
              wbm0_sel_o <= 4'b1111;
              wbm0_cyc_o <= 1'b1;
              wbm0_stb_o <= 1'b1;
              wbm0_we_o <= 1'b0;
            end
          end
        end
        ERROR_PRO:begin
          pc_out <= pc_now_reg;
        end
        STATE_READ:begin
          if(wbm0_ack_i) begin
            inst_out <= wbm0_dat_i;
            wbm0_cyc_o <= 1'b0;
            wbm0_stb_o <= 1'b0;
            pc_out <= pc_now_reg;
          end
        end
        WAIT_FAULT:begin
          if(!stall_i) begin
            pc_now_reg <= pc_next_reg;
            error <= 4'b0;
          end
        end
      endcase
   end
end

assign va_o = pc_now_reg;
assign error_code = error;

endmodule

/* =================== IF SEG END =================*/