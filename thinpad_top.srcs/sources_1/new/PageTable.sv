`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/11/25 22:47:25
// Design Name: 
// Module Name: PageTable
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module PageTable(
    input wire clk,
    input wire rst,

    input wire [31:0] va_i,         // input virtual address
    input wire req_i,               // '1' for a request
    input wire [1:0] req_type_i,    // 00: execute, 01: read, 10: reserved, 11: store
    input wire [1:0] privilege_i,   // 00: U, 01: S, 11: M
    output reg [31:0] pa_o,         // output physical address
    output reg ack_o,               // ACK for a translation request

    output reg [31:0] pte_addr_o,   // SRAM address, used to read a PTE
    output reg pte_please_o,        // request for a PTE
    input wire [31:0] pte_i,        // PTE from CPU, valid when `pte_ready_i` is '1'
    input wire pte_ready_i,         // '1' means `pte_i` is valid

    output reg [3:0] fault_code_o,  // the same in `exception.h`
    output reg fault_o,             // '1' for fault, '0' for no fault

    input wire [31:0] satp_i        // value of CSR register satp
    );

    typedef enum logic [2:0] {
        STATE_IDLE = 0,
        STATE_WAIT_1 = 1,
        STATE_CHECK_1 = 2,
        STATE_WAIT_0 = 3,
        STATE_CHECK_0 = 4
    } state_t;

    state_t state;
    state_t nextstate;

    logic u, x, w, r, v;
    logic access_fault;
    logic permission_fault;     // reserved for PMA / PMP check

    always_ff @(posedge clk) begin
        if(rst) begin
            state <= STATE_IDLE;
        end
        else begin
            state <= nextstate;
        end
    end

    always_comb begin
        u = pte_i[4];
        x = pte_i[3];
        w = pte_i[2];
        r = pte_i[1];
        v = pte_i[0];

        access_fault = 0;       // reserved for PMA / PMP check

        permission_fault = (privilege_i == 2'b00 && !u)     // no permission to U mode
                        || (req_type_i == 2'b00 && !x)      // no permission to execute
                        || (req_type_i == 2'b01 && !r)      // no permission to read
                        || (req_type_i == 2'b11 && !w);     // no permission to write (store)
    end

    always_comb begin
        if(rst) begin
            pa_o = 32'd0;
            ack_o = 0;
            pte_addr_o = 32'd0;
            pte_please_o = 0;
            fault_o = 0;
            fault_code_o = 4'd0;
            nextstate = STATE_IDLE;
        end
        else begin
            case(state)
                STATE_IDLE: begin
                    pa_o = 32'd0;
                    ack_o = 0;
                    pte_addr_o = 32'd0;
                    pte_please_o = 0;
                    fault_o = 0;
                    fault_code_o = 4'd0;
                    nextstate = req_i ? STATE_WAIT_1 : STATE_IDLE;
                end

                STATE_WAIT_1: begin
                    pa_o = 32'd0;
                    ack_o = 0;
                    pte_addr_o = {satp_i[19:0], va_i[31:22], 2'b00};
                    pte_please_o = !pte_ready_i;
                    fault_o = 0;
                    fault_code_o = 4'd0;
                    nextstate = pte_ready_i ? STATE_CHECK_1 : STATE_WAIT_1;
                end

                STATE_CHECK_1: begin
                    if(!v || ((!r) && w)) begin     // invalid PTE
                        pa_o = 32'd0;
                        ack_o = 1;
                        pte_addr_o = 32'd0;
                        pte_please_o = 0;
                        fault_o = 1;
                        fault_code_o = {2'b11, req_type_i};
                        nextstate = STATE_IDLE;
                    end
                    else if(r || x) begin           // valid leaf PTE
                        if(permission_fault || pte_i[19:10] != 10'd0) begin  // no permission or misaligned superpage
                            pa_o = 32'd0;
                            ack_o = 1;
                            pte_addr_o = 32'd0;
                            pte_please_o = 0;
                            fault_code_o = {2'b11, req_type_i};
                            fault_o = 1;
                            nextstate = STATE_IDLE;
                        end
                        else begin
                            pa_o = {pte_i[31:22], va_i[21:12], va_i[11:0]};
                            ack_o = 1;
                            pte_addr_o = 0;
                            pte_please_o = 0;
                            fault_code_o = 4'd0;
                            fault_o = 0;
                            nextstate = STATE_IDLE;
                        end
                    end
                    else begin      // pointer, go to the next layer
                        pa_o = 0;
                        ack_o = 0;
                        pte_addr_o = 0;
                        pte_please_o = 0;
                        fault_code_o = 4'd0;
                        fault_o = 0;
                        nextstate = STATE_WAIT_0;
                    end
                end

                STATE_WAIT_0: begin
                    pa_o = 32'd0;
                    ack_o = 0;
                    pte_addr_o = {pte_i[29:10], va_i[21:12], 2'b00};
                    pte_please_o = !pte_ready_i;
                    fault_o = 0;
                    fault_code_o = 4'd0;
                    nextstate = pte_ready_i ? STATE_CHECK_0 : STATE_WAIT_0;
                end

                STATE_CHECK_0: begin
                    if(!v || ((!r) && w)) begin     // invalid PTE
                        pa_o = 32'd0;
                        ack_o = 1;
                        pte_addr_o = 32'd0;
                        pte_please_o = 0;
                        fault_o = 1;
                        fault_code_o = {2'b11, req_type_i};
                        nextstate = STATE_IDLE;
                    end
                    else if(r || x) begin           // valid leaf PTE
                        if(permission_fault) begin  // no permission
                            pa_o = 32'd0;
                            ack_o = 1;
                            pte_addr_o = 32'd0;
                            pte_please_o = 0;
                            fault_code_o = {2'b11, req_type_i};
                            fault_o = 1;
                            nextstate = STATE_IDLE;
                        end
                        else begin
                            pa_o = {pte_i[29:10], va_i[11:0]};
                            ack_o = 1;
                            pte_addr_o = 0;
                            pte_please_o = 0;
                            fault_code_o = 4'd0;
                            fault_o = 0;
                            nextstate = STATE_IDLE;
                        end
                    end
                    else begin                  // pointer at the last layer
                        pa_o = 32'd0;
                        ack_o = 0;
                        pte_addr_o = 0;
                        pte_please_o = 0;
                        fault_code_o = {2'b11, req_type_i};
                        fault_o = 1;
                        nextstate = STATE_IDLE;
                    end
                end

                default: begin
                    pa_o = 32'd0;
                    ack_o = 0;
                    pte_addr_o = 0;
                    pte_please_o = 0;
                    fault_code_o = 4'd0;
                    fault_o = 0;
                    nextstate = STATE_IDLE;
                end
            endcase
        end
    end


endmodule
