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
// Description: 2-way associated TLB with 5-bit TLBI, 64 entries in total
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
    input wire [31:0] flush_addr_i, // address to be flushed, all-zero means flush the whole TLB
    input wire flush_i,             // '1' for a flush instruction
    input wire [1:0] req_type_i,    // 00: execute, 01: read, 10: reserved, 11: store
    input wire [1:0] privilege_i,   // 00: U, 01: S, 11: M
    output reg [31:0] pa_o,         // [comb] output physical address
    output reg ack_o,               // [comb] ACK for a translation request

    output reg [31:0] pte_addr_o,   // [comb] SRAM address, used to read a PTE
    output reg pte_please_o,        // [comb] request for a PTE
    input wire [31:0] pte_i,        // PTE from CPU, valid when `pte_ready_i` is '1'
    input wire pte_ready_i,         // '1' means `pte_i` is valid

    output reg [3:0] fault_code_o,  // [comb] the same in `exception.h`
    output reg fault_o,             // [comb] '1' for fault, '0' for no fault

    input wire [31:0] satp_i        // value of CSR register satp
    );

    typedef enum logic [2:0] {
        STATE_IDLE = 0,             // wait for a request
        STATE_FLUSH = 1,            // flush TLB
        STATE_TLB = 2,              // look up, check, and update reference info
        STATE_WAIT_1 = 3,           // not found in TLB, request PTE from CPU
        STATE_UPD_CHECK_1 = 4,      // check permission etc., update TLB if a superpage is found
        STATE_WAIT_0 = 5,           // request a leaf PTE from CPU
        STATE_UPD_CHECK_0 = 6       // check permission etc., update TLB
    } state_t;

    state_t state;                  // [ff]
    state_t nextstate;              // [comb]

    // 2-way associated TLB, with 2*32=64 entries in total
    // [39:25]: TLBT; [24:5]: PPN; [4:0]: uxwrv
    logic [39:0] tlb [0:63];            // [ff]
    logic [31:0] tlb_first_first;       // [ff] whether [0] entry is referenced earlier

    logic [39:0] selected_tlb_entry;    // [ff]
    logic [4:0] tlbi;                   // [comb*]
    logic [5:0] tlb_i0;                 // [comb*]
    logic [5:0] tlb_i1;                 // [comb*]
    logic pte_u, pte_x, pte_w, pte_r, pte_v;    // [comb*]
    logic tlb_u, tlb_x, tlb_w, tlb_r, tlb_v;    // [comb*]
    logic pte_permission_fault;         // [comb*]
    logic tlb_permission_fault;         // [comb*]
    integer i;      // used in initialization

    always_ff @(posedge clk) begin
        if(rst) begin
            state <= STATE_IDLE;
        end
        else begin
            state <= nextstate;
        end
    end

    always_comb begin
        pte_u = pte_i[4];
        pte_x = pte_i[3];
        pte_w = pte_i[2];
        pte_r = pte_i[1];
        pte_v = pte_i[0];

        tlbi = va_i[16:12];
        tlb_i0 = {va_i[16:12], 1'b0};
        tlb_i1 = {va_i[16:12], 1'b1};

        tlb_u = selected_tlb_entry[4];
        tlb_x = selected_tlb_entry[3];
        tlb_w = selected_tlb_entry[2];
        tlb_r = selected_tlb_entry[1];
        tlb_v = selected_tlb_entry[0];

        pte_permission_fault = (privilege_i == 2'b00 && !pte_u)     // no permission to U mode
                            || (req_type_i == 2'b00 && !pte_x)      // no permission to execute
                            || (req_type_i == 2'b01 && !pte_r)      // no permission to read
                            || (req_type_i == 2'b11 && !pte_w);     // no permission to write (store)
        
        tlb_permission_fault = (privilege_i == 2'b00 && !tlb_u)     // no permission to U mode
                            || (req_type_i == 2'b00 && !tlb_x)      // no permission to execute
                            || (req_type_i == 2'b01 && !tlb_r)      // no permission to read
                            || (req_type_i == 2'b11 && !tlb_w);     // no permission to write (store)
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < 64; i++) begin
                tlb[i] <= 40'b0;
            end
            tlb_first_first <= 32'hffff_ffff;
            selected_tlb_entry <= 40'b0;
        end
        else begin
            case(nextstate)
                STATE_IDLE: begin
                    selected_tlb_entry <= 40'b0;
                end

                STATE_FLUSH: begin
                    if(|flush_addr_i) begin     // flush address
                        if(tlb[tlb_i0][0] && tlb[tlb_i0][39:25] == va_i[31:17]) begin
                            tlb[tlb_i0][0] <= 32'b0;
                            tlb_first_first[tlbi] <= 1;
                        end
                        if(tlb[tlb_i1][0] && tlb[tlb_i1][39:25] == va_i[31:17]) begin
                            tlb[tlb_i1][0] <= 32'b0;
                            tlb_first_first[tlbi] <= 0;
                        end
                    end
                    else begin                  // flush the whole TLB
                        for(i = 0; i < 64; i++) begin
                            tlb[i] <= 40'b0;
                        end
                        tlb_first_first <= 32'hffff_ffff;
                    end
                end

                STATE_TLB: begin
                    if(tlb[tlb_i0][0] && tlb[tlb_i0][39:25] == va_i[31:17]) begin
                        selected_tlb_entry <= tlb[tlb_i0];
                        tlb_first_first[tlbi] <= 0;
                    end
                    else if(tlb[tlb_i1][0] && tlb[tlb_i1][39:25] == va_i[31:17]) begin
                        selected_tlb_entry <= tlb[tlb_i1];
                        tlb_first_first[tlbi] <= 1;
                    end
                    else begin  // TLB entry not found
                        selected_tlb_entry <= 32'b0;
                    end
                end

                STATE_UPD_CHECK_1: begin
                    if(pte_x | pte_w | pte_r) begin     // not a pointer PTE, update TLB
                        if(tlb_first_first[tlbi]) begin
                            tlb[tlb_i0] <= {va_i[31:17], pte_i[29:20], va_i[21:12], pte_u, pte_x, pte_w, pte_r, pte_v};
                            tlb_first_first[tlbi] <= 0;
                        end
                        else begin
                            tlb[tlb_i1] <= {va_i[31:17], pte_i[29:20], va_i[21:12], pte_u, pte_x, pte_w, pte_r, pte_v};
                            tlb_first_first[tlbi] <= 1;
                        end
                    end
                end

                STATE_UPD_CHECK_0: begin
                    if(tlb_first_first[tlbi]) begin
                        tlb[tlb_i0] <= {va_i[31:17], pte_i[29:10], pte_u, pte_x, pte_w, pte_r, pte_v};
                        tlb_first_first[tlbi] <= 0;
                    end
                    else begin
                        tlb[tlb_i1] <= {va_i[31:17], pte_i[29:10], pte_u, pte_x, pte_w, pte_r, pte_v};
                        tlb_first_first[tlbi] <= 1;
                    end
                end
            endcase
        end
    end

    always_comb begin
        if(rst) begin
            pa_o = 32'd0;
            ack_o = 0;
            pte_addr_o = 32'd0;
            pte_please_o = 0;
            fault_code_o = 4'd0;
            fault_o = 0;
            nextstate = STATE_IDLE;
        end
        else begin
            case(state)
                STATE_IDLE: begin
                    pa_o = 32'd0;
                    ack_o = 0;
                    pte_addr_o = 32'd0;
                    pte_please_o = 0;
                    fault_code_o = 4'd0;
                    fault_o = 0;
                    nextstate = flush_i ? STATE_FLUSH : (req_i ? STATE_TLB : STATE_IDLE);
                end

                STATE_FLUSH: begin
                    pa_o = 32'd0;
                    ack_o = 0;
                    pte_addr_o = 32'd0;
                    pte_please_o = 0;
                    fault_code_o = 4'd0;
                    fault_o = 0;
                    nextstate = STATE_IDLE;
                end

                STATE_TLB: begin
                    if(selected_tlb_entry[0]) begin     // TLB entry found, check permission
                        if((!tlb_r) && tlb_w) begin     // invalid TLB
                            pa_o = 32'd0;
                            ack_o = 1;
                            pte_addr_o = 32'd0;
                            pte_please_o = 0;
                            fault_code_o = {2'b11, req_type_i};
                            fault_o = 1;
                            nextstate = STATE_IDLE;
                        end
                        else if(tlb_r || tlb_x) begin           // valid leaf PTE
                            if(tlb_permission_fault) begin      // no permission
                                pa_o = 32'd0;
                                ack_o = 1;
                                pte_addr_o = 32'd0;
                                pte_please_o = 0;
                                fault_code_o = {2'b11, req_type_i};
                                fault_o = 1;
                                nextstate = STATE_IDLE;
                            end
                            else begin                          // all right
                                pa_o = {selected_tlb_entry[24:5], va_i[11:0]};     // PPN + VPO
                                ack_o = 1;
                                pte_addr_o = 32'd0;
                                pte_please_o = 0;
                                fault_code_o = 4'd0;
                                fault_o = 0;
                                nextstate = STATE_IDLE;
                            end
                        end
                        else begin      // pointer should not exist in TLB, treat as a miss
                            pa_o = 32'd0;
                            ack_o = 0;
                            pte_addr_o = 32'd0;
                            pte_please_o = 0;
                            fault_code_o = 4'd0;
                            fault_o = 0;
                            nextstate = STATE_WAIT_1;
                        end
                    end
                    else begin          // TLB miss, read PTE instead
                        pa_o = 32'd0;
                        ack_o = 0;
                        pte_addr_o = 32'd0;
                        pte_please_o = 0;
                        fault_code_o = 4'd0;
                        fault_o = 0;
                        nextstate = STATE_WAIT_1;
                    end
                end

                STATE_WAIT_1: begin
                    pa_o = 32'd0;
                    ack_o = 0;
                    pte_addr_o = {satp_i[19:0], va_i[31:22], 2'b00};    // base + VPN[1]
                    pte_please_o = !pte_ready_i;
                    fault_o = 0;
                    fault_code_o = 4'd0;
                    nextstate = pte_ready_i ? STATE_UPD_CHECK_1 : STATE_WAIT_1;
                end

                STATE_UPD_CHECK_1: begin
                    if(!pte_v || ((!pte_r) && pte_w)) begin     // invalid PTE
                        pa_o = 32'd0;
                        ack_o = 1;
                        pte_addr_o = 32'd0;
                        pte_please_o = 0;
                        fault_o = 1;
                        fault_code_o = {2'b11, req_type_i};
                        nextstate = STATE_IDLE;
                    end
                    else if(pte_r || pte_x) begin           // valid leaf PTE
                        if(pte_permission_fault || pte_i[19:10] != 10'd0) begin  // no permission or misaligned superpage
                            pa_o = 32'd0;
                            ack_o = 1;
                            pte_addr_o = 32'd0;
                            pte_please_o = 0;
                            fault_code_o = {2'b11, req_type_i};
                            fault_o = 1;
                            nextstate = STATE_IDLE;
                        end
                        else begin
                            pa_o = {pte_i[29:20], va_i[21:12], va_i[11:0]};     // PPN[1] + VPN[0] + VPO
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
                    nextstate = pte_ready_i ? STATE_UPD_CHECK_0 : STATE_WAIT_0;
                end

                STATE_UPD_CHECK_0: begin
                    if(!pte_v || ((!pte_r) && pte_w)) begin     // invalid PTE
                        pa_o = 32'd0;
                        ack_o = 1;
                        pte_addr_o = 32'd0;
                        pte_please_o = 0;
                        fault_o = 1;
                        fault_code_o = {2'b11, req_type_i};
                        nextstate = STATE_IDLE;
                    end
                    else if(pte_r || pte_x) begin           // valid leaf PTE
                        if(pte_permission_fault) begin      // no permission
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
