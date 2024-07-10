`timescale 1ns/100ps

module commit_stage(
    // Input
    input         clock,                // system clock
    input         reset,                // system reset

    // From ROB
    input ROB_ENTRY head_entry,
    input head_ready,
    input commit_rob_tag,

    // Output  
    // To Memory and regfiles
    output COMMIT_PACKET  cmt_packet_out,

);


  assign cmt_packet_out.valid = head_entry.valid && head_ready;
  assign cmt_packet_out.data_out = head_entry.value;
  assign cmt_packet_out.mem_size = head_entry.mem_size;

  // for memory stage
  assign cmt_packet_out.wr_mem = (cmt_packet_out.valid && head_entry.wr_mem);
  assign cmt_packet_out.mem_address = head_entry.dest_addr;

  // for register write back
  assign cmt_packet_out.reg_wr_idx_out = head_entry.dest_reg;
  assign cmt_packet_out.reg_wr_en_out  = (cmt_packet_out.valid && head_entry.dest_reg != `ZERO_REG);

  // for map table
  assign cmt_packet_out.rob_tag = commit_rob_tag;

endmodule // module commit_stage
