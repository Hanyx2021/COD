/*==================== ID confict ================*/
module ID_confict(                           // for DATA FORWARDING
  input wire  [5:0]  idexe_rs1,              // register rs1 for stage EXE
  input wire  [5:0]  idexe_rs2,              // register rs2 for stage EXE
  input wire  [5:0]  exemem_rd,              // the dest register of instruction LOAD to be used at stage MEM
  input wire  [5:0]  memwb_rd,               // the register to which rd writes back at stage WB
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
      rs1_out = 'b0;
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
      rs2_out = 'b0;
    end
end

endmodule
/*==================== ID confict END ================*/

/*==================== Confict Controller ================*/
module conflict_controller(
  input wire branch_conflict_i,
  input wire data_ack_i,
  input wire pc_stall_i,
  input wire exe_page_i,
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
  else if(data_ack_i || pc_stall_i || exe_page_i) begin
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
  if(data_ack_i || exe_page_i) begin
    idexe_stall_o = '1;
    exemem_stall_o = '1;
    memwb_stall_o = '1;
  end
  else begin
    idexe_stall_o = '0;
    exemem_stall_o = '0;
  end
  if(data_ack_i || pc_stall_i || exe_page_i) begin
    pc_ack_o = '1;
  end
  else begin
    pc_ack_o = '0;
  end
end
endmodule
/*==================== Confict Controller END================*/
