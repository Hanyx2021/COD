/* =================== IF SEG===============*/
module SEG_IF(
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] pc_in,            // 输入的PC，可能�?�过BEQ传�??
    output reg [31:0] pc_out,           // 输出的PC
    output reg [31:0] inst_out,         // 输出的指�??????
    input wire branch_i,                // 是否读取传入的PC，为1则读�??????
    input wire stall_i,                 // 是否正常状�?�可以更新pc_now_reg
    output reg pc_finish,

    output reg [31:0] wbm0_adr_o,      // 应当输出PC取指�??????
    output reg [31:0] wbm0_dat_o,      // 无用
    input  wire [31:0] wbm0_dat_i,      // 输入的指令结�??????
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
    output reg  [4:0]  rf_raddr_a,
    input  wire [31:0] rf_rdata_a,
    output reg  [4:0]  rf_raddr_b,
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
logic [4:0] rs1, rs2;
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
        7'b1100011:                     // BEQ
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
            end
        7'b0000011:                     // LB
            begin
                rs1 = instr[19:15];
            end
        7'b0100011:                     // SB,SW
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
            end
        7'b0010011:                     // ADDI,ANDI
            begin
                rs1 = instr[19:15];
            end
        7'b0110011:                    // ADD
            begin
                rs1 = instr[19:15];
                rs2 = instr[24:20];
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
    output wire [31:0] raddr_out,
    output reg  [31:0] alu_a,
    output reg  [31:0] alu_b,
    output reg  [ 3:0] alu_op,
    input  wire [31:0] alu_y,
    output reg  [31:0] alu_out,
    output reg branch_o,
    output reg [31:0] pc_branch
    );

logic [31:0] instr;
logic [31:0] pc;
logic [31:0] a_data_reg;
logic [31:0] b_data_reg;
logic [31:0] alu_reg;
logic [31:0] addr_reg;
logic [6:0] instr_type;

always_comb begin
    instr = inst_in;
    pc = pc_in;
    a_data_reg = rdata_a;
    b_data_reg = rdata_b;
    instr_type = instr[6:0];
    if(instr_type != 7'b1100011) begin
      branch_o = 1'b0;
    end
    case(instr_type)
        7'b0110111:                     // LUI
            begin
                alu_reg = instr[31:12] << 12;
            end
        7'b1100011:                     // BEQ
            begin
                if(a_data_reg == b_data_reg) begin
                    pc_branch = instr[31] ? pc + {19'b1111_1111_1111_1111_111,instr[31],instr[7],instr[30:25],instr[11:8],1'b0} : pc + {19'b0000_0000_0000_0000_000,instr[31],instr[7],instr[30:25],instr[11:8],1'b0};
                    branch_o = 1'b1;
                end
                else begin
                    branch_o = 1'b0;
                end
            end
        7'b0000011:                     // LB
            begin
                alu_a = a_data_reg;
                alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:20]} : {20'b0000_0000_0000_0000_0000,instr[31:20]};
                alu_op = 4'b0001;
                addr_reg = alu_y;
            end
        7'b0100011:
            begin
                if(instr[14:12] == 3'b000)     // SB
                begin
                    alu_a = a_data_reg;
                    alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:25],instr[11:7]} : {20'b0000_0000_0000_0000_0000,instr[31:25],instr[11:7]};
                    alu_op = 4'b0001;
                    addr_reg = alu_y;
                    alu_reg = b_data_reg[7:0];
                end
                else if(instr[14:12] == 3'b010)  // SW
                begin
                    alu_a = a_data_reg;
                    alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:25],instr[11:7]} : {20'b0000_0000_0000_0000_0000,instr[31:25],instr[11:7]};
                    alu_op = 4'b0001;
                    addr_reg = alu_y;
                    alu_reg = b_data_reg;
                end
            end
        7'b0010011:
            begin
            if(instr[14:12] == 3'b000)          // ADDI
            begin
                alu_a = a_data_reg;
                alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:20]} : {20'b0000_0000_0000_0000_0000,instr[31:20]};
                alu_op = 4'b0001;
                alu_reg = alu_y;
            end
            else if (instr[14:12] == 3'b111)    // ANDI
            begin
                alu_a = a_data_reg;
                alu_b = instr[31] ? {20'b1111_1111_1111_1111_1111,instr[31:20]} : {20'b0000_0000_0000_0000_0000,instr[31:20]};
                alu_op = 4'b0011;
                alu_reg = alu_y;
            end
            end
        7'b0110011:                             // ADD
            begin
                alu_a = a_data_reg;
                alu_b = b_data_reg;
                alu_op = 4'b0001;
                alu_reg = alu_y;
            end
    endcase
end

assign pc_out = pc;
assign inst_out = instr;
assign raddr_out = pc ? addr_reg:0;
assign alu_out = pc ? alu_reg:0;

endmodule

/* =================== EXE SEG END===============*/

/* =================== MEM SEG ===============*/

module SEG_MEM(                    // 待填�??????
    input wire clk_i,
    input wire rst_i,

    input wire [31:0] inst_in,
    input wire [31:0] pc_in,
    input wire [31:0] alu_in,
    input wire [31:0] raddr_in,
    output reg [31:0] data_out,
    output reg [31:0] inst_out,
    output reg [4:0] load_rd,
    output reg data_ack_o,

    output reg [31:0] wbm1_adr_o,      // 读写地址
    output reg [31:0] wbm1_dat_o,      // 写入的数�??????
    input  wire [31:0] wbm1_dat_i,      // 读出的数�??????
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
    if(inst_in[14:12] == 3'b010) begin
      wbm1_sel_o = 4'b1111;
    end
    else begin
      wbm1_sel_o = 4'b0001;
    end
    if(state == STATE_IDLE) begin
      if(instr_type == 7'b0000011) begin
        load_rd = inst_in[11:7];
      end
      else begin
        load_rd = 5'b00000;
      end
    end
    else begin
      if(instr[6:0] == 7'b0000011) begin
        load_rd = instr[11:7];
      end
      else begin
        load_rd = 5'b00000;
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
        if(instr_type == 7'b0000011)begin          // LB
          nextstate = STATE_READ;
        end
        else if(instr_type == 7'b0100011) begin    // SW，SB
          nextstate = STATE_WRITE;
        end
        else begin                                 // 不需要读�??????
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
          else begin                              // 不需要读�??????
            data_out <= alu_in;
            data_ack_o <= 1'b0;
          end
        end
        STATE_READ:begin
          if(wbm1_ack_i) begin                      // LB
            data_out <= wbm1_dat_i;
            //data_out <= wbm1_dat_i[7] ? {6'hffffff,wbm1_dat_i[7:0]} : {6'h000000,wbm1_dat_i[7:0]};
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

        output reg  [4:0]  rf_waddr,
        output reg  [31:0] rf_wdata,
        output reg  rf_we
    );

logic [31:0] instr;

always_comb begin
    instr = inst_in;
    if(instr[6:0] != 7'b1100011)
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
    input wire [4:0] load_rd2,
    output reg [4:0] idexe_rs1,
    output reg [4:0] idexe_rs2,
    output reg if_stall_o,
    input wire stall_i,
    input wire bubble_i,
    input wire pc_finish
);

reg [31:0] pc;
reg [31:0] instr;
reg [31:0] a;
reg [31:0] b;
reg [4:0] rs1;
reg [4:0] rs2;
reg [4:0] load_rd;

assign pc_out = pc;
assign inst_out = instr;
assign a_out = a;
assign b_out = b;
assign idexe_rs1 = rs1;
assign idexe_rs2 = rs2;

always_comb begin
  if (inst_in[6:0] != 7'b0110111) begin
    rs1 = inst_in[19:15];
  end
  else begin
    rs1 = 5'b00000;
  end
  if (inst_in[6:0] == 7'b1100011 || inst_in[6:0] == 7'b0100011 || inst_in[6:0] == 7'b0110011) begin
    rs2 = inst_in[24:20];
  end
  else begin
    rs2 = 5'b00000;
  end
  if(instr[6:0] == 7'b0000011) begin
    load_rd = instr[11:7];
  end
  else begin
    load_rd = 5'b00000;
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
    output reg [4:0] exemem_rd,
    input wire stall_i,
    input wire bubble_i,
    input wire pc_finish
);

reg [31:0] pc;
reg [31:0] instr;
reg [31:0] alu;
reg [31:0] b;
reg [4:0] rd;

assign pc_out = pc;
assign inst_out = instr;
assign alu_out = alu;
assign b_out = b;
assign exemem_rd = rd;

always_comb begin
  if (inst_in[6:0] != 7'b1100011 && inst_in[6:0] != 7'b0100011) begin
    rd = inst_in[11:7];
  end
  else begin
    rd = 5'b00000;
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
    output reg [4:0] memwb_rd,
    input wire stall_i,
    input wire bubble_i,
    input wire pc_finish
);

reg [31:0] data;
reg [31:0] instr;
reg [4:0] rd;

assign data_out = data;
assign inst_out = instr;
assign memwb_rd = rd;

always_comb begin
  if (inst_in[6:0] != 7'b1100011 && inst_in[6:0] != 7'b0100011) begin
    rd = inst_in[11:7];
  end
  else begin
    rd = 5'b00000;
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
module ID_confict(
  input wire  [4:0]  idexe_rs1,              // exe阶段寄存�?????1
  input wire  [4:0]  idexe_rs2,              // exe阶段寄存�?????2
  input wire  [4:0]  exemem_rd,              // mem阶段�?????要LOAD的寄存器
  input wire  [4:0]  memwb_rd,               // wb阶段�?????要写回的寄存�?????
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