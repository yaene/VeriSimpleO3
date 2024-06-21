module maptable_tb();

  // Clock and reset signals
  logic clock;
  logic reset;
  logic commit;
  INST inst;
  INST inst_out;

  // Instantiate the maptable module
  maptable uut (
    .clock(clock),
    .reset(reset),
    .commit(commit),
    .inst(inst),
    .inst_out(inst_out)
  );

  // Clock generation
  always #5 clock = ~clock;

  // Task to apply stimulus to the maptable
  task apply_inst(input INST i, input logic c);
    begin
      inst = i;
      commit = c;
      #10;
    end
  endtask

  // Initial block to provide stimulus
  initial begin
    // Initialize signals
    clock = 0;
    reset = 1;
    commit = 0;
    inst = '0;

    // Apply reset
    #15 reset = 0;

    // Apply some instructions for decode
    INST temp;
    temp.r.rs1 = 1;
    temp.r.rs2 = 2;
    temp.r.rd = 3;


    $display("Starting decode instructions:");
    apply_inst(temp, 0);
    $display("Inst decoded with phys_rs1: %0d, phys_rs2: %0d, old_phys_rd: %0d, new_phys_rd: %0d", inst_out.r.phys_rs1, inst_out.r.phys_rs2, inst_out.r.old_phys_rd, inst_out.r.new_phys_rd);

    temp.r.rs1 = 2;
    temp.r.rs2 = 3;
    temp.r.rd = 4; 

    apply_inst(temp, 0);
    $display("Inst decoded with phys_rs1: %0d, phys_rs2: %0d, old_phys_rd: %0d, new_phys_rd: %0d", inst_out.r.phys_rs1, inst_out.r.phys_rs2, inst_out.r.old_phys_rd, inst_out.r.new_phys_rd);

    // Apply some instructions for commit
    temp.r.rs1 = 1;
    temp.r.rs2 = 2;
    temp.r.rd = 3;

    $display("Starting commit instructions:");
    apply_inst(temp, 1);
    $display("Inst committed with phys_rs1: %0d, phys_rs2: %0d, old_phys_rd: %0d, new_phys_rd: %0d", inst_out.r.phys_rs1, inst_out.r.phys_rs2, inst_out.r.old_phys_rd, inst_out.r.new_phys_rd);

    temp.r.rs1 = 2;
    temp.r.rs2 = 3;
    temp.r.rd = 4;

    apply_inst(temp, 1);
    $display("Inst committed with phys_rs1: %0d, phys_rs2: %0d, old_phys_rd: %0d, new_phys_rd: %0d", inst_out.r.phys_rs1, inst_out.r.phys_rs2, inst_out.r.old_phys_rd, inst_out.r.new_phys_rd);

    $stop;
  end

endmodule