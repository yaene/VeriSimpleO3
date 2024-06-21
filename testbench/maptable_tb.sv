`timescale 1ns/100ps

module maptable_tb;

  // Declare testbench signals
  logic clock;
  logic reset;
  logic commit;
  INST inst;
  logic [4:0] old_phys_rd;
  MAPPED_REG_PACKET mapped_reg_packet;

  // Instantiate the maptable module
  maptable uut (
    .clock(clock),
    .reset(reset),
    .commit(commit),
    .inst(inst),
    .old_phys_rd(old_phys_rd),
    .mapped_reg_packet(mapped_reg_packet)
  );

  // Clock generation
  always #5 clock = ~clock; // 100MHz clock

  initial begin
    // Initialize signals
    clock = 0;
    reset = 0;
    commit = 0;
    inst = '0;
    old_phys_rd = '0;

    // Apply reset
    reset = 1;
    #20;
    reset = 0;

    // Test case 1: simple instruction mapping
    inst.r.rs1 = 1;
    inst.r.rs2 = 2;
    inst.r.rd = 3;

    #10; // wait for clock edge to capture the instruction

    // Check the results
    assert(mapped_reg_packet.phys_rs1 == 5'b00001);
    assert(mapped_reg_packet.phys_rs2 == 5'b00010);
    assert(mapped_reg_packet.old_phys_rd == 5'b00011);
    assert(mapped_reg_packet.new_phys_rd != 5'b00000);

    // Test case 2: commit instruction
    commit = 1;
    old_phys_rd = mapped_reg_packet.old_phys_rd;

    #30; // wait for clock edge to capture the commit

    $finish;
  end

endmodule