module lab5_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // TODO: ������Ҫ�Ŀ����źţ����簴�����أ�
    input wire [ADDR_WIDTH-1:0] sram_addr,
    // wishbone master
    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output reg [ADDR_WIDTH-1:0] wb_adr_o,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o
);

  // TODO: ʵ��ʵ�� 5 ���ڴ�+���� Master
typedef enum logic [3:0] {
  STATE_IDLE = 0,
  STATE_READ_WAIT_ACTION = 1,
  STATE_READ_WAIT_CHECK = 2,
  STATE_READ_DATA_ACTION = 3,
  STATE_READ_DATA_DONE = 4,
  STATE_WRITE_SRAM_ACTION = 5,
  STATE_WRITE_SRAM_DONE = 6,
  STATE_WRITE_WAIT_ACTION = 7,
  STATE_WRITE_WAIT_CHECK = 8,
  STATE_WRITE_DATA_ACTION = 9,
  STATE_WRITE_DATA_DONE = 10
} state_t;

state_t state;
state_t nextstate;
reg [ADDR_WIDTH-1:0] addr_reg;
reg [DATA_WIDTH:0] data_reg;
logic check_reg;
integer i;

always_ff @(posedge clk_i) begin
  if(rst_i) begin
    state <= STATE_IDLE;
  end
  else begin
    state <= nextstate;
  end
end

always_comb  begin
  if(rst_i) begin
    nextstate = STATE_IDLE;
  end
  else begin
    case(state)
      STATE_IDLE:begin
        if(i == 10)begin
        nextstate = STATE_IDLE;
        end
        else begin
          nextstate = STATE_READ_WAIT_ACTION;
        end
      end
      STATE_READ_WAIT_ACTION:begin
        if(wb_ack_i)begin
          nextstate = STATE_READ_WAIT_CHECK;
        end
        else begin
          nextstate = STATE_READ_WAIT_ACTION;
        end
        end
      STATE_READ_WAIT_CHECK:begin
        if(check_reg == 0) begin
          nextstate = STATE_READ_WAIT_ACTION;
        end
        else begin
          nextstate = STATE_READ_DATA_ACTION;
        end
      end
      STATE_READ_DATA_ACTION:begin
        if(wb_ack_i)begin
          nextstate = STATE_READ_DATA_DONE;
        end
        else begin
          nextstate = STATE_READ_DATA_ACTION;
        end
      end
      STATE_READ_DATA_DONE:begin
        nextstate = STATE_WRITE_SRAM_ACTION;
      end
      STATE_WRITE_SRAM_ACTION:begin
        if(wb_ack_i)begin
          nextstate = STATE_WRITE_SRAM_DONE;
        end
        else begin
          nextstate = STATE_WRITE_SRAM_ACTION;
        end
      end
      STATE_WRITE_SRAM_DONE:begin
        nextstate = STATE_WRITE_WAIT_ACTION;
      end
      STATE_WRITE_WAIT_ACTION:begin
        if(wb_ack_i)begin
          nextstate = STATE_WRITE_WAIT_CHECK;
        end
        else begin
          nextstate = STATE_WRITE_WAIT_ACTION;
        end
      end
      STATE_WRITE_WAIT_CHECK:begin
        if(check_reg == 0) begin
          nextstate = STATE_WRITE_WAIT_ACTION;
        end
        else begin
          nextstate = STATE_WRITE_DATA_ACTION;
        end
      end
      STATE_WRITE_DATA_ACTION:begin
        if(wb_ack_i)begin
          nextstate = STATE_WRITE_DATA_DONE;
        end
        else begin
          nextstate = STATE_WRITE_DATA_ACTION;
        end
      end
      STATE_WRITE_DATA_DONE:begin
        nextstate = STATE_IDLE;
      end
    endcase
  end
end

always_ff @(posedge clk_i)begin
  if(rst_i)begin
    addr_reg <= sram_addr;
    i <= 0;
    wb_cyc_o <= 1'b0;
    wb_stb_o <= 1'b0;
  end
  else begin
    case(state)
      STATE_IDLE:begin
        if(i == 10)begin
          wb_cyc_o <= 1'b0;
          wb_stb_o <= 1'b0;
        end
        else begin
        wb_cyc_o <= 1'b1;
        wb_stb_o <= 1'b1;
        wb_we_o <= 1'b0;
        wb_adr_o <= 'h10000005;
        wb_sel_o <= 4'b0010;
        end
      end
      STATE_READ_WAIT_ACTION:begin
        if(wb_ack_i)begin
          wb_cyc_o <= 1'b0;
          wb_stb_o <= 1'b0;
          check_reg <= wb_dat_i[8];
        end
        end
      STATE_READ_WAIT_CHECK:begin
        wb_cyc_o <= 1'b1;
        wb_stb_o <= 1'b1;
        wb_we_o <= 1'b0;
        if(check_reg == 0) begin
          wb_adr_o <= 'h10000005;
          wb_sel_o <= 4'b0010;
        end
        else begin
          wb_adr_o <= 'h10000000;
          wb_sel_o <= 4'b0001;
        end
      end
      STATE_READ_DATA_ACTION:begin
        if(wb_ack_i)begin
          wb_cyc_o <= 1'b0;
          wb_stb_o <= 1'b0;
          data_reg <= wb_dat_i;
        end
      end
      STATE_READ_DATA_DONE:begin
        wb_cyc_o <= 1'b1;
        wb_stb_o <= 1'b1;
        wb_sel_o <= 4'b0001;
        wb_adr_o <= ((addr_reg >> 2) << 2) + 4 * i;
        wb_dat_o <= data_reg;
        wb_we_o <= 1'b1;
      end
      STATE_WRITE_SRAM_ACTION:begin
        if(wb_ack_i) begin
          wb_cyc_o <= 1'b0;
          wb_stb_o <= 1'b0;
        end
      end
      STATE_WRITE_SRAM_DONE:begin
        wb_cyc_o <= 1'b1;
        wb_stb_o <= 1'b1;
        wb_we_o <= 1'b0;
        wb_adr_o <= 'h10000005;
        wb_sel_o <= 4'b0010;
      end
      STATE_WRITE_WAIT_ACTION:begin
        if(wb_ack_i)begin
          wb_cyc_o <= 1'b0;
          wb_stb_o <= 1'b0;
          check_reg <= wb_dat_i[13];
        end
      end
      STATE_WRITE_WAIT_CHECK:begin
        wb_cyc_o <= 1'b1;
        wb_stb_o <= 1'b1;
        if(check_reg == 0) begin
          wb_adr_o <= 'h10000005;
          wb_sel_o <= 4'b0010;
          wb_we_o <= 1'b0;
        end
        else begin
          wb_adr_o <= 'h10000000;
          wb_sel_o <= 4'b0001;
          wb_we_o <= 1'b1;
          wb_dat_o <= data_reg;
        end
      end
      STATE_WRITE_DATA_ACTION:begin
        if(wb_ack_i)begin
          wb_cyc_o <= 1'b0;
          wb_stb_o <= 1'b0;
          wb_we_o <= 1'b0;
        end
      end
      STATE_WRITE_DATA_DONE:begin
        i <= i + 1;
      end
    endcase
  end
end

endmodule
