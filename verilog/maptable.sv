`ifndef __MAPTABLE_V__
`define __MAPTABLE_V__

`timescale 1ns/100ps
module maptable(
  input logic clock,
  input logic reset,
  input logic commit,
  input INST inst,
  input logic [4:0] old_phys_rd,
  output MAPPED_REG_PACKET mapped_reg_packet
);
  
  // Maptable and free list queue 
  logic [4:0] maptable[31:0];
  logic [4:0] free_list_queue [31:0];
  logic [4:0] queue_head, queue_tail;

  // Function to get a new physical register from free list queue
  function logic [4:0] new_phys_reg();
    new_phys_reg = (queue_head != queue_tail) ? free_list_queue[queue_head] : '0;
    queue_head <= queue_head + 1;
    return new_phys_reg;
  endfunction

  // Function to free a physical register and add it to the free list queue
  function void free_phys_reg(logic [4:0] register);
    free_list_queue[queue_tail] = register;
    queue_tail <= queue_tail + 1;
  endfunction

  // TODO: at recovery

  always_ff @(posedge clock) begin
    if (reset) begin
      integer i;
      for (i = 0; i < 32; i++) begin
        maptable[i] <= i;
        free_list_queue[i] <= i;
      end
      queue_head <= 17;
      queue_tail <= 0;
    end
    if (commit) begin
      free_phys_reg(old_phys_rd);
    end else begin
      mapped_reg_packet.phys_rs1 <= maptable[inst.r.rs1];
      mapped_reg_packet.phys_rs2 <= maptable[inst.r.rs2];
      mapped_reg_packet.old_phys_rd <= maptable[inst.r.rd];
      mapped_reg_packet.new_phys_rd <= new_phys_reg();
      maptable[inst.r.rd] <= mapped_reg_packet.new_phys_rd;
    end
  end

endmodule
`endif