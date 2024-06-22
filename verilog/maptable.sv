`ifndef __MAPTABLE_V__
`define __MAPTABLE_V__

`timescale 1ns/100ps

module maptable(
  // Inputs
  input logic clock,
  input logic reset,
  input logic commit,
  input INST inst, //inst from decoding stage
  input logic [`ROB_TAG_LEN-1:0] rob_tag_entry_in, // rob entry from ROB
  input logic [4:0] rd, // dest_reg from decoding stage
  input logic [4:0] rd_commit, // dest_reg from CDB
  input logic [`ROB_TAG_LEN-1:0] rob_tag_entry_commit, // rob entry from CDB
  // Outputs
  output MAPTABLE_PACKET maptable_packet_rs1,
  output MAPTABLE_PACKET maptable_packet_rs2
);
  
  // Maptable and ready_tag
  logic [`ROB_TAG_LEN-1:0] maptable[31:0];
  logic ready_tag_table[31:0];


  always_ff @(posedge clock) begin
    if (reset) begin
      integer i;
      for (i = 0; i < 32; i++) begin
        maptable[i] = 0;
        ready_tag_table[i] = 0;
      end
    end
    if (commit) begin
      if ((rd_commit != `ZERO_REG) && (rob_tag_entry_commit == maptable[rd_commit]))
        ready_tag_table[rd_commit] = 1;
    end
    maptable_packet_rs1.rob_tag_val = maptable[inst.r.rs1];
    maptable_packet_rs2.rob_tag_val = maptable[inst.r.rs2];    
    maptable_packet_rs1.rob_tag_ready = ready_tag_table[inst.r.rs1];
    maptable_packet_rs2.rob_tag_ready = ready_tag_table[inst.r.rs2];
    if (rd != `ZERO_REG) begin
      maptable[rd] = rob_tag_entry_in;
      ready_tag_table[rd] = 0;
    end
  end

endmodule
`endif