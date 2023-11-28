/* =================== MEM SEG ===============*/

module SEG_MEM(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] inst_in,
    (* DONT_TOUCH = "1" *) input wire [31:0] pc_in,
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
    (* DONT_TOUCH = "1" *) input  wire wbm1_err_i,
    (* DONT_TOUCH = "1" *) input  wire wbm1_rty_i,
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
      default:begin
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