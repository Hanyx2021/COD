module sram_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,

    parameter SRAM_ADDR_WIDTH = 20,
    parameter SRAM_DATA_WIDTH = 32,

    localparam SRAM_BYTES = SRAM_DATA_WIDTH / 8,
    localparam SRAM_BYTE_WIDTH = $clog2(SRAM_BYTES)
) (
    // clk and reset
    input wire clk_i,
    input wire rst_i,

    // wishbone slave interface                            这些与master交互
    input wire wb_cyc_i,                                  // 总使能信号，和wb_syb_i保持�???�???
    input wire wb_stb_i,                                  // master是否发�?�请求，valid_o
    output reg wb_ack_o,                                  // slave是否完成请求，ready_i
    input wire [ADDR_WIDTH-1:0] wb_adr_i,                 // master想要读写的地�???，addr_o
    input wire [DATA_WIDTH-1:0] wb_dat_i,                 // master想要写入的数据，data_o
    output reg [DATA_WIDTH-1:0] wb_dat_o,                 // master从slave读取的数据，slave_o
    input wire [DATA_WIDTH/8-1:0] wb_sel_i,               // 读写的字节使能，be_o
    input wire wb_we_i,                                   // master想要读还是写，we_o�???1为写�???0为读

    // sram interface                                       这些与sram绑定
    output reg [SRAM_ADDR_WIDTH-1:0] sram_addr,             // ram地址
    inout wire [SRAM_DATA_WIDTH-1:0] sram_data,             // ram数据
    output reg sram_ce_n,                                   // ram片�?�，工作�???0
    output reg sram_oe_n,                                   // 输出使能，写�???1，读�???0
    output reg sram_we_n,                                   // 读入使能，读�???1，写�???0
    output reg [SRAM_BYTES-1:0] sram_be_n                   // ram字节使能
);

  // TODO: 实现 SRAM 控制�???
typedef enum logic [2:0] {
  STATE_IDLE = 0,
  STATE_READ = 1,
  STATE_READ_2 = 2,
  STATE_WRITE = 3,
  STATE_WRITE_2 = 4,
  STATE_WRITE_3 = 5,
  STATE_DONE = 6
} state_t;

state_t state;
state_t nextstate;
wire [DATA_WIDTH-1:0] sram_data_i_comb;
reg [DATA_WIDTH-1:0] sram_data_o_reg;
reg sram_data_t_reg;

assign sram_data = sram_data_t_reg ? 32'bz : sram_data_o_reg;
assign sram_data_i_comb = sram_data;

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
      if(wb_stb_i && wb_cyc_i)begin
        if(wb_we_i)begin
          nextstate = STATE_WRITE;
        end
        else begin
          nextstate = STATE_READ;
        end
      end
      else begin
        nextstate = STATE_IDLE;
      end
    end
    STATE_READ:begin
      nextstate = STATE_READ_2;
    end
    STATE_READ_2:begin
      nextstate = STATE_DONE;
    end
    STATE_WRITE:begin
      nextstate = STATE_WRITE_2;
    end
    STATE_WRITE_2:begin
      nextstate = STATE_WRITE_3;
    end
    STATE_WRITE_3:begin
      nextstate = STATE_DONE;
    end
    STATE_DONE:begin
      nextstate = STATE_IDLE;
    end
 endcase
end
end

always_ff @(posedge clk_i)begin
  if(rst_i)begin
    sram_ce_n <= 1'b1;
    sram_oe_n <= 1'b0;
    sram_we_n <= 1'b1;
    wb_ack_o <= 1'b0;
    sram_data_t_reg <= 1'b1;
    sram_data_o_reg <= 32'b0;
  end
  else begin
    case(state)
      STATE_IDLE:begin
        if(wb_stb_i && wb_cyc_i)begin
          sram_ce_n = 1'b0;
          sram_addr <= (wb_adr_i >> 2);
          sram_be_n <= ~wb_sel_i;
          if(wb_we_i)begin
            sram_we_n <= 1'b1;
            sram_oe_n <= 1'b1;
            sram_data_t_reg <= 1'b0;
            sram_data_o_reg <= wb_dat_i;
          end
          else begin
            sram_oe_n <= 1'b0;
            sram_we_n <= 1'b1;
            sram_data_t_reg <= 1'b1;
          end
      end
    end
      STATE_READ:begin
      end
      STATE_READ_2:begin
        wb_ack_o <= 1'b1;
        wb_dat_o <= sram_data_i_comb;
        sram_ce_n <= 1'b1;
        sram_oe_n <= 1'b1;
      end
      STATE_WRITE:begin
        sram_we_n <= 1'b0;
      end
      STATE_WRITE_2:begin
        sram_we_n <= 1'b1;
      end
      STATE_WRITE_3:begin
        wb_ack_o <= 1'b1;
        sram_ce_n <= 1'b1;
        sram_data_t_reg <= 1'b1;
      end
      STATE_DONE:begin
        wb_ack_o <= 1'b0;
      end
    endcase
  end
end

endmodule
