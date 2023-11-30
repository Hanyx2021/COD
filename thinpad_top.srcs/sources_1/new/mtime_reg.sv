module mtime_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    // clk and reset
    input wire clk_i,
    input wire rst_i,

    // wishbone slave interface
    input wire wb_cyc_i,
    input wire wb_stb_i,
    output reg wb_ack_o,
    input wire [ADDR_WIDTH-1:0] wb_adr_i,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH/8-1:0] wb_sel_i,
    input wire wb_we_i,                                   // 0 read;1 write
    output reg timeout_o
);

typedef enum logic [1:0] {
  STATE_IDLE = 0,
  STATE_READ_AND_WRITE = 1,
  STATE_DONE = 2
} state_t;

state_t state;
state_t nextstate;

reg [DATA_WIDTH-1:0] mtime_l;
reg [DATA_WIDTH-1:0] mtime_h;
reg [DATA_WIDTH-1:0] mtimecmp_l;
reg [DATA_WIDTH-1:0] mtimecmp_h;
logic timeout;

assign timeout_o = timeout;

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
    timeout = '0;
  end
  else begin
    if(mtime_h > mtimecmp_h) begin
      timeout = '1;
    end
    else if(mtime_h == mtimecmp_h) begin
      if(mtime_l >= mtimecmp_l) begin
        timeout = '1;
      end
      else begin
        timeout = '0;
      end
    end
    else begin
      timeout = '0;
    end
  case(state)
    STATE_IDLE:begin
      if(wb_stb_i && wb_cyc_i)begin
        nextstate = STATE_READ_AND_WRITE;
      end
      else begin
        nextstate = STATE_IDLE;
      end
    end
    STATE_READ_AND_WRITE:begin
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
    wb_ack_o <= 1'b0;
    mtime_l <= 32'b0;
    mtime_h <= 32'b0;
    mtimecmp_l <= 32'b0;
    mtimecmp_h <= 32'b0;
  end
  else begin
    case(state)
      STATE_IDLE:begin
        if(timeout == '0) begin
          if(mtime_l == 'hFFFF_FFFF) begin
            mtime_h <= mtime_h + 1;
          end
          mtime_l <= mtime_l + 1;
        end
      end
      STATE_READ_AND_WRITE:begin
        if(wb_we_i) begin
            if(wb_adr_i == 'h0200BFF8) begin
                mtime_l <= wb_dat_i;
            end
            else if(wb_adr_i == 'h0200BFFc) begin
                mtime_h <= wb_dat_i;
            end
            else if(wb_adr_i == 'h02004000) begin
                mtimecmp_l <= wb_dat_i;
            end
            else if(wb_adr_i == 'h02004004)begin
                mtimecmp_h <= wb_dat_i;
            end
            else begin
            end
        end
        else begin
          if(wb_adr_i == 'h0200BFF8) begin
              wb_dat_o <= mtime_l;
          end
          else if(wb_adr_i == 'h0200BFFc) begin
              wb_dat_o <= mtime_h;
          end
          else if(wb_adr_i == 'h02004000) begin
              wb_dat_o <= mtimecmp_l;
          end
          else if(wb_adr_i == 'h02004004)begin
              wb_dat_o <= mtimecmp_h;
          end
          else begin
              wb_dat_o <= '0;
          end
        end
        wb_ack_o <= 1'b1;
      end
      STATE_DONE:begin
        wb_ack_o <= 1'b0;
      end
    endcase
  end
end

endmodule