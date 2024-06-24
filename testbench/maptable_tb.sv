`timescale 1ns / 100ps

module maptable_tb;

  // Declare inputs as logic variables
  logic clock;
  logic reset;
  logic commit;
  logic [4:0] rd_commit;
  logic [`ROB_TAG_LEN-1:0] rob_entry_in;
  logic [`ROB_TAG_LEN-1:0] rob_entry_wb;
  logic [`ROB_TAG_LEN-1:0] rob_entry_commit;
  logic [4:0] rd;
  logic [4:0] rd_wb;
  logic valid_wb;
  INST inst;
  MAPTABLE_PACKET maptable_packet_rs1, maptable_packet_rs2;

  // Instantiate the maptable module
  maptable uut (
    .clock(clock),
    .reset(reset),
    .commit(commit),
    .rd_commit(rd_commit),
    .rob_entry_commit(rob_entry_commit),
    .rob_entry_in(rob_entry_in),
    .inst(inst),
    .rd(rd),
    .rd_wb(rd_wb),
    .rob_entry_wb(rob_entry_wb),
    .valid_wb(valid_wb),
    .maptable_packet_rs1(maptable_packet_rs1),
    .maptable_packet_rs2(maptable_packet_rs2)
  );

  // Clock generation
  initial begin
    clock = 1'b0;
    forever #5 clock = ~clock; // 10ns period
  end

  // Test stimulus
  initial begin
    // Initialize inputs
    reset = 1;
    commit = 0;
    rob_entry_commit = 0;
    rob_entry_in = 0;
    inst.r.rs1 = 0;
    inst.r.rs2 = 0;
    rd = 0;
    rd_wb = 0;
    rob_entry_wb = 0;
    valid_wb = 0;
    
    // Wait for some time and then release reset
    #10;
    reset = 0;

    // Test based on P6 slide
    // cycle 1
    rd = 1;
    rob_entry_in = 1;
    inst.r.rs1 = 0;
    inst.r.rs2 = 3;
    #10;
    assert(maptable_packet_rs1.rob_tag_val == 0);
    assert(maptable_packet_rs1.rob_tag_ready == 0);
    assert(maptable_packet_rs2.rob_tag_val == 0);
    assert(maptable_packet_rs2.rob_tag_ready == 0);
    // cycle 2
    rd = 2;
    rob_entry_in = 2;
    inst.r.rs1 = 0;
    inst.r.rs2 = 1;
    #10;
    assert(maptable_packet_rs1.rob_tag_val == 0);
    assert(maptable_packet_rs1.rob_tag_ready == 0);
    assert(maptable_packet_rs2.rob_tag_val == 1);
    assert(maptable_packet_rs2.rob_tag_ready == 0);
    // cycle 3
    rd = 0;
    rob_entry_in = 3;
    inst.r.rs1 = 2;
    inst.r.rs2 = 3;
    #10;
    assert(maptable_packet_rs1.rob_tag_val == 2);
    assert(maptable_packet_rs1.rob_tag_ready == 0);
    assert(maptable_packet_rs2.rob_tag_val == 0);
    assert(maptable_packet_rs2.rob_tag_ready == 0);
    // cycle 4
    rd = 3;
    rd_wb = 1;
    rob_entry_wb = 1;
    valid_wb = 1;
    rob_entry_in = 4;
    inst.r.rs1 = 3;
    inst.r.rs2 = 4;
    #10;
    assert(maptable_packet_rs1.rob_tag_val == 0);
    assert(maptable_packet_rs1.rob_tag_ready == 0);
    assert(maptable_packet_rs2.rob_tag_val == 0);
    assert(maptable_packet_rs2.rob_tag_ready == 0);
    assert(uut.maptable[1] == 1);
    assert(uut.ready_tag_table[1] == 1);
    // cycle 5
    valid_wb = 0;
    rd = 1;
    rob_entry_in = 5;
    inst.r.rs1 = 0;
    inst.r.rs2 = 3;
    #10;
    assert(maptable_packet_rs1.rob_tag_val == 0);
    assert(maptable_packet_rs1.rob_tag_ready == 0);
    assert(maptable_packet_rs2.rob_tag_val == 4);
    assert(maptable_packet_rs2.rob_tag_ready == 0);
    // cycle 6
    rd = 2;
    rob_entry_in = 6;
    inst.r.rs1 = 0;
    inst.r.rs2 = 1;
    #10;
    assert(maptable_packet_rs1.rob_tag_val == 0);
    assert(maptable_packet_rs1.rob_tag_ready == 0);
    assert(maptable_packet_rs2.rob_tag_val == 5);
    assert(maptable_packet_rs2.rob_tag_ready == 0);
    // cycle 7
    rd_wb = 3;
    rob_entry_wb = 4;
    valid_wb = 1;
    rd = 0;
    inst.r.rs1 = 0;
    inst.r.rs2 = 0;
    #10;
    assert(uut.maptable[3] == 4);
    assert(uut.ready_tag_table[3] == 1);
    // cycle 8
    rd_wb = 2;
    rob_entry_wb = 2;
    #10;
    assert(uut.maptable[2] == 6);
    assert(uut.ready_tag_table[2] == 0);
    // cycle 9
    rd_wb = 1;
    rob_entry_wb = 5;
    rd = 0;
    rob_entry_in = 7;
    inst.r.rs1 = 2;
    inst.r.rs2 = 3;
    #10;
    assert(maptable_packet_rs1.rob_tag_val == 6);
    assert(maptable_packet_rs1.rob_tag_ready == 0);
    assert(maptable_packet_rs2.rob_tag_val == 4);
    assert(maptable_packet_rs2.rob_tag_ready == 1);
    assert(uut.maptable[1] == 5);
    assert(uut.ready_tag_table[1] == 1);
    // test commit
    valid_wb = 0;
    commit = 1;
    rd_commit = 2;
    rob_entry_commit = 6;
    #10;
    assert(uut.maptable[2] == 0);
    assert(uut.ready_tag_table[2]==0);
    #10;
    rd_commit = 1;
    rob_entry_commit = 3;
    #10;
    assert(uut.maptable[1] != 0);
    $finish;
  end

endmodule