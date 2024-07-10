`timescale 1ns / 1ps

module testbench;
  logic clk;
  logic reset;
  CDB_DATA cdb;
  logic is_st_ld_type;
  ID_EX_PACKET id_packet_out;
  MAPTABLE_PACKET maptable_packet_rs1;
  MAPTABLE_PACKET maptable_packet_rs2;
  logic [`ROB_TAG_LEN-1:0] alloc_slot;
  logic rs_st_ld_full;
  logic rs_alu_full;
  logic ldst_exec_stall, alu_exec_stall;
  INSTR_READY_ENTRY ready_inst_entry_st_ld;
  INSTR_READY_ENTRY ready_inst_entry_alu;

  
  ReservationStation #(.NO_WAIT_RS2(1)) ST_LD_RS(
    .clk(clk),
    .reset(reset),
    .cdb(cdb), 
    .alloc_enable(is_st_ld_type),
    .id_packet_out(id_packet_out),
    .maptable_packet_rs1(maptable_packet_rs1),
    .maptable_packet_rs2(maptable_packet_rs2),
    .alloc_slot(alloc_slot),
    .rs_full(rs_st_ld_full),
    .exec_stall(ldst_exec_stall),
    .ready_inst_entry(ready_inst_entry_st_ld)
  );

  ReservationStation #(.NO_WAIT_RS2(0)) ALU_RS (
    .clk(clk),
    .reset(reset),
    .cdb(cdb), 
    .alloc_enable(~is_st_ld_type),
    .id_packet_out(id_packet_out),
    .maptable_packet_rs1(maptable_packet_rs1),
    .maptable_packet_rs2(maptable_packet_rs2),
    .alloc_slot(alloc_slot),
    .rs_full(rs_alu_full),
    .exec_stall(alu_exec_stall),
    .ready_inst_entry(ready_inst_entry_alu)
  );
  always_comb begin
      if (id_packet_out.wr_mem || id_packet_out.rd_mem)
          is_st_ld_type = 1;
      else
          is_st_ld_type = 0;
  end

  initial begin
    // Initialize signals
    clk = 0;
    reset = 0;
    cdb = 0;
    maptable_packet_rs1 = 0;
    maptable_packet_rs2 = 0;
    alloc_slot = 0;

    // Apply reset
    reset = 1;
    @(negedge clk)
    reset = 0;

    // ldf X(r1), f1, [r1]=5
    id_packet_out.wr_mem = 0;
    id_packet_out.rd_mem = 1;
    id_packet_out.rs1_value = 5;
    maptable_packet_rs1.rob_tag_val = 0;
    alloc_slot = 1;
    
    @(negedge clk)
    //mulf f0, f1, f2, [f0]=10
    id_packet_out.wr_mem = 0;
    id_packet_out.rd_mem = 0;
    maptable_packet_rs2.rob_tag_val = 1;
    maptable_packet_rs2.rob_tag_ready = 0; 
    id_packet_out.rs1_value = 10;
    alloc_slot = 2;
    ldst_exec_stall = 1;
    $display("In this cycle, LD should be ready, with rs1_value equals to 5, rd_tag = 1 ");
    $display("Cycle %d: rs_st_ld_full = %d, ready_inst_entry_rd_tag = %h,  ready_inst_entry_rs1_value = %h,", $time/10-1, rs_st_ld_full, ready_inst_entry_st_ld.rd_tag, ready_inst_entry_st_ld.rs1_value);
    assert(ready_inst_entry_st_ld.ready == 1);
    assert(ready_inst_entry_st_ld.valid == 1);
    assert(ready_inst_entry_st_ld.rs1_value == 5);
    assert(ready_inst_entry_st_ld.rd_tag == 1);
    
    
    @(negedge clk)
    //stf f2, Z(r1)
    id_packet_out.wr_mem = 1;
    id_packet_out.rd_mem = 0;
    id_packet_out.rs1_value = 5;
    maptable_packet_rs2.rob_tag_val = 2;
    maptable_packet_rs2.rob_tag_ready = 0;
    alloc_slot = 3;
    ldst_exec_stall = 0;
    // ld st is stalled, but store is still added
    assert(ready_inst_entry_st_ld.valid == 1);
    assert(ready_inst_entry_st_ld.ready == 1);
    assert(ready_inst_entry_st_ld.rs1_value == 5);
    assert(ready_inst_entry_st_ld.rd_tag == 1);
    
    @(negedge clk)
    //addi r1,4, r1
    id_packet_out.wr_mem = 0;
    id_packet_out.rd_mem = 0;
    id_packet_out.rs1_value = 5;
    alloc_slot = 4;
    cdb.valid = 1;
    cdb.rob_tag = 1;
    cdb.value = 5;
    // store is ready now
    assert(ready_inst_entry_st_ld.valid == 1);
    assert(ready_inst_entry_st_ld.ready == 1);
    assert(ready_inst_entry_st_ld.rs1_value == 5);
    assert(ready_inst_entry_st_ld.rd_tag == 3);

    @(negedge clk)
    //ldf X(r1),f1
    id_packet_out.wr_mem = 0;
    id_packet_out.rd_mem = 1;
    maptable_packet_rs2.rob_tag_val = 4;
    maptable_packet_rs2.rob_tag_ready = 0;
    alloc_slot = 5;

    // no ldst instruction should be ready now
    assert(ready_inst_entry_st_ld.valid == 0);  

    @(negedge clk)
    $display("In this cycle, mulf f0,f1,f2 should be ready, with rd_tag = 2, rs2_tag = 1, rs1_value = 10, rs2_value = 5 ");
    $display("Cycle %d: rs_alu_full = %d, ready_inst_entry_rd_tag = %h,  ready_inst_entry_rs2_tag = %h, ready_inst_entry_rs1_value = %h, ready_inst_entry_rs2_value = %h,", $time/10-1, rs_alu_full, ready_inst_entry_alu.rd_tag, ready_inst_entry_alu.rs2_tag, ready_inst_entry_alu.rs1_value, ready_inst_entry_alu.rs2_value);
    assert(ready_inst_entry_alu.rs2_tag == 1);
    assert(ready_inst_entry_alu.rs2_value == 5);
    assert(ready_inst_entry_alu.rs1_value == 10);
    assert(ready_inst_entry_alu.rd_tag == 2);
    
    //mulf f0, f1, f2
    id_packet_out.wr_mem = 0;
    id_packet_out.rd_mem = 0;
    id_packet_out.rs1_value = 10;
    maptable_packet_rs2.rob_tag_val = 5;
    maptable_packet_rs2.rob_tag_ready = 0;
    alloc_slot = 6;

    @(negedge clk)
    //CDB broadcast [r1]
    id_packet_out.wr_mem = 1;
    id_packet_out.rd_mem = 0;
    cdb.valid = 1;
    cdb.rob_tag = 4;
    cdb.value = 9;

    @(negedge clk)
    //CDB broadcast [f2]
    cdb.rob_tag = 2;
    cdb.value = 50;


    $display("rs_alu_full = %d, ready_inst_entry = %h", rs_alu_full, ready_inst_entry_alu);
  end

  always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clk = ~clk;
	end
endmodule
