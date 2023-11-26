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
    output reg wbm0_cyc_o,
    output reg [3:0] error_code
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