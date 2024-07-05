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

  COMMIT_PACKET cmt_pack;

  assign cmt_pack.valid = head_entry.valid;
  assign cmt_pack.data_out = head_entry.value;
  assign cmt_pack.mem_size = head_entry.mem_size;

  // for memory stage
  assign cmt_pack.wr_mem = (head_ready && head_entry.valid);
  assign cmt_pack.mem_address = head_entry.dest_addr;

  // for register write back
  assign cmt_pack.reg_wr_idx_out = head_entry.dest_reg;
  assign cmt_pack.reg_wr_en_out  = head_entry.dest_reg != `ZERO_REG;

  always_ff @(posedge clock) begin
    if(reset) begin
      cmt_packet_out <= '{0, 0, 0, 0, 0, 0, 0};
    end else begin
      cmt_packet_out <= cmt_pack;
    end
  end

endmodule // module commit_stage