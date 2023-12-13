module flash_controller(
    input wire clk_i,
    input wire rst_i,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    output reg wb_ack_o,
    input wire [31:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wire [3:0] wb_sel_i,
    input wire wb_we_i,
    output reg [22:0] flash_a_o,
    inout wire [15:0] flash_d,
    output reg flash_rp_o,
    output reg flash_ce_o,
    output reg flash_oe_o
);


typedef enum logic [1:0] {
    IDLE = 0,
    READ = 1,
    READ_DONE = 2
} state_t;
state_t state, next_state;

// 状态转移
always @(posedge clk_i) begin
    if (rst_i) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

always_comb begin
    next_state = IDLE;
    case(state)
        IDLE: begin
            if (wb_cyc_i && wb_stb_i && !wb_we_i) begin
                next_state = READ;
            end
            else begin
                next_state = IDLE;
            end
        end

        READ: begin
            next_state = READ_DONE;  
        end

        READ_DONE: begin
            next_state = IDLE;
        end
    endcase
end

// 单字节读取，不做地址对齐
wire [22:0] flash_addr;
wire [1:0] addr_sel;
assign flash_addr = wb_adr_i[22:0];
assign addr_sel = wb_adr_i[1:0];


wire [31:0] wb_data;
wire [7:0] flash_data_i_low;

assign flash_d = 8'bz;
assign flash_data_i_low = flash_d[7:0];
assign wb_data = $signed(flash_data_i_low) << (8 * addr_sel);


// 数据转移
always_comb begin
    if (rst_i) begin
        flash_rp_o = 1;  // 挂起rp
        flash_oe_o = 1;
        flash_ce_o = 1;
        flash_a_o  = 0;
    end

    case(state) 
        IDLE: begin
            if (wb_cyc_i && wb_stb_i && !wb_we_i) begin
                flash_oe_o = 0;
                flash_ce_o = 0;
                flash_a_o = flash_addr;
            end
            else begin
            end
        end

        READ: begin
            flash_oe_o = 0;
            flash_ce_o = 0;
            flash_a_o = flash_addr;
        end

        READ_DONE: begin
            flash_oe_o = 1;
            flash_ce_o = 1;
            flash_a_o = flash_addr;
        end
    endcase
end


// wishbone 数据输出
always_ff @ (posedge clk_i) begin
    if (rst_i) begin
        wb_ack_o <= 0;
    end

    case(state)
        IDLE: begin
            wb_ack_o <= 0;
        end

        READ: begin
            if (wb_cyc_i && wb_stb_i) begin
                if (wb_we_i) begin       // write
                    // pass
                end else begin          // read
                    wb_dat_o <= wb_data;
                end
                wb_ack_o <= 1;
            end
        end

        READ_DONE: begin
            wb_ack_o <= 0;
        end
    endcase

end
endmodule