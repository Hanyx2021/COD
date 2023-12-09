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
    else if(instr[14:12] == 3'b000) begin    // LB,SB,LBU
      if(instr[6:0] == 7'b0000011)                      // LB,LBU
      begin
        wbm1_sel_o = 4'b1111;
      end
      else begin
        wbm1_sel_o = 4'b1 << (raddr_in & 32'h3);     // SB
      end
    end
    else if (instr[14:12] == 3'b001) begin   // LH,SH,LHU
      if(instr[6:0] == 7'b0000011)                      // LH,LHU
      begin
        wbm1_sel_o = 4'b1111;
      end
      else begin
        wbm1_sel_o = 4'b11 << (raddr_in & 32'h2);    // SH
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
        if(instr_type == 7'b0000011)begin          // LB,LW,LH,LBU,LWU,LHU
          nextstate = STATE_READ;
        end
        else if(instr_type == 7'b0100011) begin    // SW,SB,SH
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
          if(instr_type == 7'b0100011) begin             // SB,SW,SH
            wbm1_cyc_o <= 1'b1;
            wbm1_stb_o <= 1'b1;
            wbm1_we_o <= 1'b1;
            wbm1_adr_o <= raddr_in & ~3;
            if(inst_in[14:12] == 3'b000) begin                     // SB
              case(raddr_in[1:0])
                2'b00: wbm1_dat_o <= {24'b0,alu_in[7:0]};
                2'b01: wbm1_dat_o <= {16'b0,alu_in[7:0],8'b0};
                2'b10: wbm1_dat_o <= {8'b0,alu_in[7:0],16'b0};
                2'b11: wbm1_dat_o <= {alu_in[7:0],24'b0};
              endcase
            end
            else if(inst_in[14:12] == 3'b010) begin                // SW
              wbm1_dat_o <= alu_in;
            end
            else begin                                            // SH
              if(raddr_in[1]) begin
                wbm1_dat_o <= {alu_in[15:0],16'b0};
              end
              else begin
                wbm1_dat_o <= {16'b0,alu_in[15:0]};
              end
            end
            data_ack_o <= 1'b1;
          end
          else if(instr_type == 7'b0000011) begin        // LB,LW,LH,LBU,LHU
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
          if(wbm1_ack_i) begin                      // LB,LW,LH,LBU,LHU
            if(instr[14:12] == 3'b010) begin // LW
              data_out <= wbm1_dat_i; 
            end
            else if (instr[14:12] == 3'b000) begin // LB
              case(wbm1_adr_o[1:0])
                  2'b00: begin data_out[7:0] <= wbm1_dat_i[7:0]; data_out[31:8] <= {24{wbm1_dat_i[7]}};end
                  2'b01: begin data_out[7:0] <= wbm1_dat_i[15:8]; data_out[31:8] <= {24{wbm1_dat_i[15]}};end
                  2'b10: begin data_out[7:0] <= wbm1_dat_i[23:16]; data_out[31:8] <= {24{wbm1_dat_i[23]}};end
                  2'b11: begin data_out[7:0] <= wbm1_dat_i[31:24]; data_out[31:8] <= {24{wbm1_dat_i[31]}};end
              endcase
            end
            // LBU
            else if (instr[14:12] == 3'b000) begin
              case(wbm1_adr_o[1:0])
                  2'b00: data_out <= {24'b0,wbm1_dat_i[7:0]};
                  2'b01: data_out <= {24'b0,wbm1_dat_i[15:8]};
                  2'b10: data_out <= {24'b0,wbm1_dat_i[23:16]};
                  2'b11: data_out <= {24'b0,wbm1_dat_i[31:24]};
              endcase
            end
            // LH
            else if (instr[14:12] == 3'b001) begin
              case(wbm1_adr_o[1])
                  1'b0: begin data_out[15:0] <= wbm1_dat_i[15:0]; data_out[31:16] <= {16{wbm1_dat_i[15]}};end
                  1'b1: begin data_out[15:0] <= wbm1_dat_i[31:16]; data_out[31:16] <= {16{wbm1_dat_i[31]}};end
              endcase
            end
            // LHU
            else if (instr[14:12] == 3'b001) begin
              case(wbm1_adr_o[1])
                  1'b0: data_out <= {16'b0,wbm1_dat_i[15:0]};
                  1'b1: data_out <= {16'b0,wbm1_dat_i[31:16]};
              endcase
            end

            wbm1_cyc_o <= 1'b0;
            wbm1_stb_o <= 1'b0;
            data_ack_o <= 1'b0;
            wbm1_we_o <= 1'b1;
          end
        end
        STATE_WRITE:begin                          // SW,SB,SH
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