`timescale 1ns/100ps

module commit_stage(
    // Input
    input         clock,                // system clock
    input         reset,                // system reset

    // From ROB
    input ROB_ENTRY head_entry,
    input head_ready,

    // Output  
    // To Memory and regfiles
    output COMMIT_PACKET  cmt_packet_out,

);

  assign cmt_packet_out.valid = head_entry.valid;
  assign cmt_packet_out.data_out = head_entry.value;

  // for memory stage
  assign cmt_packet_out.wr_mem = (head_ready && head_entry.valid && head_ready);
  assign cmt_packet_out.mem_address = head_entry.dest_addr;

  // for register write back
  assign cmt_packet_out.reg_wr_idx_out = head_entry.dest_reg;
  assign cmt_packet_out.reg_wr_en_out  = head_entry.dest_reg != `ZERO_REG;

endmodule // module commit_stage