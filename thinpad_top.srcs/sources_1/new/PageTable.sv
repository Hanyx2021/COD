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


////////////////////////////////////////////////////////
// 1. CPU -> PT: `req_i`, `va_i`
// 2. PT -> CPU: I need `pte_addr_o`
// 3. CPU -> PT: Here's your PTE (pte_i)
// 4. PT -> CPU: I need another `pte_addr_o`
// 5. CPU -> PT: Here's your PTE (pte_i)
// 6. PT -> CPU: This is the `pa_o` you need
//
// TODO: How to handle exceptions?
////////////////////////////////////////////////////////


parameter PAGESIZE = 32;

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
    output reg req_o,               // request for a PTE
    input wire ack_i,               // ACK for a get-PTE request
    input wire [31:0] pte_i,        // PTE from SRAM
    output reg [3:0] sram_be_n,     // SRAM byte enable, ALWAYS set as '0000'

    input wire [31:0] satp_i,       // value of CSR register satp

    output reg [31:0] mcause_val_o, // value to be written to mcause
    output reg mcause_we,           // mcause write enable, '1' for write
    );

    typedef enum logic [2:0] {
        STATE_IDLE = 0,
        STATE_INIT = 1,
        STATE_VALID = 2,
        STATE_PM = 3,
        STATE_DONE = 4
    } state_t;

    state_t state;
    state_t nextstate;

    reg [31:0] va_reg;
    reg [31:0] base_addr;
    reg i;
    reg [31:0] pte;
    logic u, x, w, r, v;
    logic permission_fault;

    assign sram_we_n = 1;
    assign sram_be_n = 4'b0000;

    always_ff @(posedge clk) begin
        if(rst) begin
            state <= STATE_IDLE;
        end
        else begin
            state <= nextstate;
        end
    end

    always_comb begin
        u = pte[4];
        x = pte[3];
        w = pte[2];
        r = pte[1];
        v = pte[0];

        mcause_val_o = {30'b11, req_type_i};

        permission_fault = (privilege_i == 2'b00 && !u)     // no permission to U mode
                        || (req_type_i == 2'b00 && !x)      // no permission to execute
                        || (req_type_i == 2'b01 && !r)      // no permission to read
                        || (req_type_i == 2'b11 && !w)      // no permission to write (store)
    end

    always_comb begin
        if(rst) begin
            nextstate = STATE_IDLE;
        end
        else begin
            case(state)
                STATE_IDLE: begin
                    pa_o = 32'd0;
                    ack_o = 0;
                    pte_addr_o = 0;
                    sram_ce_n = 32'd0;
                    sram_oe_n = 0;
                    mcause_val_o = 32'd0;
                    mcause_we = 1;
                    va_reg = req_i ? va_i : va_reg;
                    base_addr = satp_i[21:0] * PAGESIZE;    // satp_i.PPN * PAGESIZE
                    i = 1;
                    pte = 32'd0;
                    nextstate = req_i ? STATE_INIT : STATE_IDLE;
                end

                STATE_INIT: begin
                    req_o = 1;
                    pte_addr_o = base_addr + (i ? va_i[31:22] : va_i[21:12]) * PAGESIZE;
                    pte = ack_i ? pte_i : pte;
                    nextstate = ack_i ? STATE_VALID : STATE_INIT;
                end

                STATE_VALID: begin
                    if(!v || ((!r) && w)) begin     // invalid PTE
                        // TODO: raise page-fault exception corresponding to req_type_i
                        nextstate = STATE_EXCEPTION;
                    end
                    else if(r && x) begin           // valid leaf PTE
                        nextstate = STATE_PM;
                    end
                    else if(i == 0) begin           // pointer at the last layer
                        // TODO: raise page-fault exception corresponding to req_type_i
                        nextstate = STATE_EXCEPTION;
                    end
                    else begin
                        i = 0;
                        pte_addr_o = base_addr + pte[19:10] * PAGESIZE;
                        nextstate = STATE_INIT;
                    end
                end

                STATE_PM: begin
                    if(permission_fault) begin
                        // TODO: raise page-fault exception corresponding to req_type_i
                        nextstate = STATE_EXCEPTION;
                    end
                    else if(i && pte[19:10] == 10'd0) begin     // misaligned superpage
                        // TODO: raise page-fault exception corresponding to req_type_i
                        nextstate = STATE_EXCEPTION;
                    end
                    else begin
                        nextstate = STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    if(i) begin
                        pa_o = {pte[31:22], va[21:12], va[11:0]};
                    end
                    else begin
                        pa_o = {pte[31:22], pte[21:12], va[11:0]};
                    end
                    nextstate = STATE_IDLE;
                end

                STATE_EXCEPTION: begin
                    mcause_we = 1;
                    nextstate = STATE_IDLE;
                end
            endcase
        end
    end


endmodule
