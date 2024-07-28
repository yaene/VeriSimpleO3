`ifndef __MAPTABLE_V__
`define __MAPTABLE_V__

`timescale 1ns/100ps

module maptable(
  // Inputs
  input logic clock,
  input logic reset,
  input enable,
  input logic commit,
  input logic [4:0] rd_commit,
  input logic [`ROB_TAG_LEN-1:0] rob_entry_commit,
  input INST inst, //inst from decoding stage
  input logic [`ROB_TAG_LEN-1:0] rob_entry_in, // rob entry from ROB
  input logic [4:0] rd, // dest_reg from decoding stage
  input logic valid_wb, // valid from wb from ROB
  input logic [4:0] rd_wb, // dest_reg from wb
  input logic [`ROB_TAG_LEN-1:0] rob_entry_wb, // rob entry from wb from ROB
  input branch_speculating,
  input branch_determined,
  input branch_misprediction,

  // Outputs
  output MAPTABLE_PACKET maptable_packet_rs1,
  output MAPTABLE_PACKET maptable_packet_rs2
);
  
  // Maptable and ready_tag
  logic [`ROB_TAG_LEN-1:0] maptable[31:0];
  logic ready_tag_table[31:0];

  logic [`ROB_TAG_LEN-1:0] next_maptable[31:0];
  logic next_ready_tag_table[31:0];

  logic [`ROB_TAG_LEN-1:0] maptable_buffer[31:0];
  logic ready_tag_table_buffer[31:0];

  logic [`ROB_TAG_LEN-1:0] next_maptable_buffer[31:0];
  logic next_ready_tag_table_buffer[31:0];


  // mapped rs1
  always_comb begin

    if (valid_wb && rob_entry_wb == maptable[inst.r.rs1]) begin
      // forwarding
      maptable_packet_rs1.rob_tag_ready = `TRUE;
    end
    else begin
      maptable_packet_rs1.rob_tag_ready = ready_tag_table[inst.r.rs1];
    end

    maptable_packet_rs1.rob_tag_val = maptable[inst.r.rs1];
  end

  // mapped rs2
  always_comb begin
    if (valid_wb && rob_entry_wb == maptable[inst.r.rs2]) begin
      // forwarding
      maptable_packet_rs2.rob_tag_ready = `TRUE;
    end
    else begin
      maptable_packet_rs2.rob_tag_ready = ready_tag_table[inst.r.rs2];
    end

    maptable_packet_rs2.rob_tag_val = maptable[inst.r.rs2];
  end

  always_ff @(posedge clock) begin
    if (reset) begin
      integer i;
      for (i = 0; i < 32; i++) begin
        maptable[i] = 0;
        ready_tag_table[i] = 0;
        maptable_buffer[i] = 0;
        ready_tag_table_buffer[i] = 0;
      end
    end
    else begin
      maptable <= next_maptable;
      ready_tag_table <= next_ready_tag_table;
      maptable_buffer <= next_maptable_buffer;
      ready_tag_table_buffer <= next_ready_tag_table_buffer;
    end
  end

  always_comb begin
    next_maptable = maptable;
    next_ready_tag_table = ready_tag_table;
    next_maptable_buffer = maptable_buffer;
    next_ready_tag_table_buffer = ready_tag_table_buffer;
    if ((valid_wb) && (rd_wb != `ZERO_REG) && (rob_entry_wb == maptable[rd_wb])) begin
      next_ready_tag_table[rd_wb] = 1;
      if (!branch_speculating) begin
        next_ready_tag_table_buffer[rd_wb] = 1;
      end
    end
    if ((commit) && (rd_commit != `ZERO_REG) && (rob_entry_commit == maptable[rd_commit])) begin
      next_maptable[rd_commit] = 0;
      next_ready_tag_table[rd_commit] = 0;
        next_maptable_buffer[rd_commit] = 0;
        next_ready_tag_table_buffer[rd_commit] = 0;
    end
    if (enable && rd != `ZERO_REG) begin
      next_maptable[rd] = rob_entry_in;
      next_ready_tag_table[rd] = 0;
      if (!branch_speculating) begin
        next_maptable_buffer[rd] = rob_entry_in;
        next_ready_tag_table_buffer[rd] = 0;
      end
    end
    // if (branch_determined) begin
    //   if (branch_misprediction) begin
    //     next_maptable = maptable_buffer;
    //     next_ready_tag_table = ready_tag_table_buffer;
    //   end
    //   else begin
    //     next_maptable_buffer = next_maptable;
    //     next_ready_tag_table_buffer = next_ready_tag_table;
    //   end
    // end
  end

endmodule
`endif
