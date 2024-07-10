`timescale 1ns/100ps

module is_stage_tb;

    parameter FU_NUM = 3;

    logic clock;
    logic reset;
    logic wb_reg_wr_en_out;
    logic [4:0] wb_reg_wr_idx_out;
    logic [`XLEN-1:0] wb_reg_wr_data_out;
    IF_ID_PACKET if_id_packet_in;
    MAPTABLE_PACKET maptable_packet_rs1;
    MAPTABLE_PACKET maptable_packet_rs2;
    logic rob_full;
    logic [`XLEN-1:0] rs1_read_rob_value;
    logic [`XLEN-1:0] rs2_read_rob_value;
    logic rs_ld_st_full;
	logic rs_alu_full;

    ID_EX_PACKET id_packet_out;
    logic rs_ld_st_enable;
	logic rs_alu_enable;
    logic alloc_enable;
    logic alloc_wr_mem;
    logic [`XLEN-1:0] alloc_value_in;    
    logic [`ROB_TAG_LEN-1:0] alloc_store_dep;
    logic alloc_value_in_valid;
	logic [2:0] alloc_mem_size;
    logic [`ROB_TAG_LEN-1:0] rs1_rob_tag;
	logic [`ROB_TAG_LEN-1:0] rs2_rob_tag;
	logic stall_if;

    logic commit;
    logic [4:0] rd_commit;
    logic [`ROB_TAG_LEN-1:0] rob_entry_in;
    logic [`ROB_TAG_LEN-1:0] rob_entry_wb;
    logic [`ROB_TAG_LEN-1:0] rob_entry_commit;
    logic [4:0] rd;
    logic [4:0] rd_wb;
    logic valid_wb;
    INST inst;

    assign inst = id_packet_out.inst;
    assign rd = id_packet_out.dest_reg_idx;

    is_stage is_0 (
        .clock(clock),
        .reset(reset),
        .wb_reg_wr_en_out(wb_reg_wr_en_out),
        .wb_reg_wr_idx_out(wb_reg_wr_idx_out),
        .wb_reg_wr_data_out(wb_reg_wr_data_out),
        .if_id_packet_in(if_id_packet_in),
        .maptable_packet_rs1(maptable_packet_rs1),
        .maptable_packet_rs2(maptable_packet_rs2),
        .rob_full(rob_full),
        .rs1_read_rob_value(rs1_read_rob_value),
        .rs2_read_rob_value(rs2_read_rob_value),
        .rs_ld_st_full(rs_ld_st_full),
	    .rs_alu_full(rs_alu_full),

        .id_packet_out(id_packet_out),
        .rs_ld_st_enable(rs_ld_st_enable),
        .rs_alu_enable(rs_alu_enable),
        .alloc_enable(alloc_enable),
        .alloc_wr_mem(alloc_wr_mem),
        .alloc_value_in(alloc_value_in),
        .alloc_store_dep(alloc_store_dep),
        .alloc_value_in_valid(alloc_value_in_valid),
        .alloc_mem_size(alloc_mem_size),
        .rs1_rob_tag(rs1_rob_tag),
        .rs2_rob_tag(rs2_rob_tag),
        .stall_if(stall_if)
    );

    maptable mt_0 (
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

    always begin
        #(`VERILOG_CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task CHECK_VAL;
        input string desc;
		input [`XLEN-1:0] actual;
        input [`XLEN-1:0] expected;
        if( actual !== expected ) begin
            $display("@@@ %s incorrect at time %4.0f", desc, $time);
            $display("@@@ expected: %h, actual: %h", expected, actual);
            $display("ENDING TESTBENCH : ERROR !");
            $finish;
        end
	endtask

    initial begin
        $dumpvars;
        $display("Simulation Start!!!");
        // Init
        reset = 0;
        clock = 0;
        rob_entry_commit = 0;
        rob_entry_in = 0;
        rd_wb = 0;
        rob_entry_wb = 0;
        valid_wb = 0;
        rob_full = 0;
        rs_alu_full = 0;
        rs_ld_st_full = 0;

        reset = 1;
        @(negedge clock)
        reset = 0;

        // #1 CYCLE
        // lw x2 0(x5):  00000000000000101010000100000011
        if_id_packet_in = '{`TRUE, 32'b00000000000000101010000100000011, 4, 0};
        rob_entry_in = 1;
        @(negedge clock)
        CHECK_VAL("#1 maptable_packet_rs1.rob_tag_val", maptable_packet_rs1.rob_tag_val, 0);
        CHECK_VAL("#1 maptable_packet_rs1.rob_tag_ready", maptable_packet_rs1.rob_tag_ready, 0);
        CHECK_VAL("#1 maptable_packet_rs2.rob_tag_val", maptable_packet_rs2.rob_tag_val, 0);
        CHECK_VAL("#1 maptable_packet_rs2.rob_tag_ready", maptable_packet_rs2.rob_tag_ready, 0);
        CHECK_VAL("#1 id_packet_out.inst", id_packet_out.inst, 32'b00000000000000101010000100000011);
        CHECK_VAL("#1 id_packet_out.wr_mem", id_packet_out.wr_mem, 0);
        CHECK_VAL("#1 id_packet_out.rd_mem", id_packet_out.rd_mem, 1);
        CHECK_VAL("#1 rs_alu_enable", rs_alu_enable, 0);
        CHECK_VAL("#1 rs_ld_st_enable", rs_ld_st_enable, 1);
        CHECK_VAL("#1 alloc_enable", alloc_enable, 1);
        CHECK_VAL("#1 alloc_wr_mem", alloc_wr_mem, 0);
        // CHECK_VAL("#1 alloc_store_dep", alloc_store_dep, 0);
        CHECK_VAL("#1 alloc_value_in_valid", alloc_value_in_valid, 1);
        CHECK_VAL("#1 rs1_rob_tag", rs1_rob_tag, 0);
        CHECK_VAL("#1 rs2_rob_tag", rs2_rob_tag, 0);

        // #2 CYCLE
        // mul x3 x1 x2: 00000010001000001000000110110011
        if_id_packet_in = '{`TRUE, 32'b00000010001000001000000110110011, 8, 4};
        rob_entry_in = 2;
        rs_ld_st_full = 1;
        @(negedge clock)
        CHECK_VAL("#2 maptable_packet_rs1.rob_tag_val", maptable_packet_rs1.rob_tag_val, 0);
        CHECK_VAL("#2 maptable_packet_rs1.rob_tag_ready", maptable_packet_rs1.rob_tag_ready, 0);
        CHECK_VAL("#2 maptable_packet_rs2.rob_tag_val", maptable_packet_rs2.rob_tag_val, 1);
        CHECK_VAL("#2 maptable_packet_rs2.rob_tag_ready", maptable_packet_rs2.rob_tag_ready, 0);
        CHECK_VAL("#2 id_packet_out.inst", id_packet_out.inst, 32'b00000010001000001000000110110011);
        CHECK_VAL("#2 id_packet_out.wr_mem", id_packet_out.wr_mem, 0);
        CHECK_VAL("#2 id_packet_out.rd_mem", id_packet_out.rd_mem, 0);
        CHECK_VAL("#2 rs_alu_enable", rs_alu_enable, 1);
        CHECK_VAL("#2 rs_ld_st_enable", rs_ld_st_enable, 0);
        CHECK_VAL("#2 alloc_enable", alloc_enable, 1);
        CHECK_VAL("#2 alloc_wr_mem", alloc_wr_mem, 0);
        // CHECK_VAL("#2 alloc_store_dep", alloc_store_dep, 0);
        CHECK_VAL("#2 alloc_value_in_valid", alloc_value_in_valid, 0);
        CHECK_VAL("#2 rs1_rob_tag", rs1_rob_tag, 0);
        CHECK_VAL("#2 rs2_rob_tag", rs2_rob_tag, 1);

        // #3 CYCLE
        // sw x3 0(x5):  00000000001100101010000000100011
        if_id_packet_in = '{`TRUE, 32'b00000000001100101010000000100011, 12, 8};
        rob_entry_in = 3;
        rs_alu_full = 1;
        @(negedge clock)
        CHECK_VAL("#3 maptable_packet_rs1.rob_tag_val", maptable_packet_rs1.rob_tag_val, 0);
        CHECK_VAL("#3 maptable_packet_rs1.rob_tag_ready", maptable_packet_rs1.rob_tag_ready, 0);
        CHECK_VAL("#3 maptable_packet_rs2.rob_tag_val", maptable_packet_rs2.rob_tag_val, 2);
        CHECK_VAL("#3 maptable_packet_rs2.rob_tag_ready", maptable_packet_rs2.rob_tag_ready, 0);
        CHECK_VAL("#3 id_packet_out.inst", id_packet_out.inst, 32'b00000000001100101010000000100011);
        CHECK_VAL("#3 id_packet_out.wr_mem", id_packet_out.wr_mem, 1);
        CHECK_VAL("#3 id_packet_out.rd_mem", id_packet_out.rd_mem, 0);
        CHECK_VAL("#3 rs_alu_enable", rs_alu_enable, 0);
        CHECK_VAL("#3 rs_ld_st_enable", rs_ld_st_enable, 0);
        CHECK_VAL("#3 alloc_enable", alloc_enable, 0);
        CHECK_VAL("#3 alloc_wr_mem", alloc_wr_mem, 1);
        CHECK_VAL("#3 alloc_store_dep", alloc_store_dep, 2);
        CHECK_VAL("#3 alloc_value_in_valid", alloc_value_in_valid, 0);
        CHECK_VAL("#3 rs1_rob_tag", rs1_rob_tag, 0);
        CHECK_VAL("#3 rs2_rob_tag", rs2_rob_tag, 2);

        // #4 CYCLE
        rs_ld_st_full = 0;
        @(negedge clock)
        CHECK_VAL("#4 maptable_packet_rs1.rob_tag_val", maptable_packet_rs1.rob_tag_val, 0);
        CHECK_VAL("#4 maptable_packet_rs1.rob_tag_ready", maptable_packet_rs1.rob_tag_ready, 0);
        CHECK_VAL("#4 maptable_packet_rs2.rob_tag_val", maptable_packet_rs2.rob_tag_val, 2);
        CHECK_VAL("#4 maptable_packet_rs2.rob_tag_ready", maptable_packet_rs2.rob_tag_ready, 0);
        CHECK_VAL("#4 id_packet_out.inst", id_packet_out.inst, 32'b00000000001100101010000000100011);
        CHECK_VAL("#4 id_packet_out.wr_mem", id_packet_out.wr_mem, 1);
        CHECK_VAL("#4 id_packet_out.rd_mem", id_packet_out.rd_mem, 0);
        CHECK_VAL("#4 rs_alu_enable", rs_alu_enable, 0);
        CHECK_VAL("#4 rs_ld_st_enable", rs_ld_st_enable, 1);
        CHECK_VAL("#4 alloc_enable", alloc_enable, 1);
        CHECK_VAL("#4 alloc_wr_mem", alloc_wr_mem, 1);
        CHECK_VAL("#4 alloc_store_dep", alloc_store_dep, 2);
        CHECK_VAL("#4 alloc_value_in_valid", alloc_value_in_valid, 0);
        CHECK_VAL("#4 rs1_rob_tag", rs1_rob_tag, 0);
        CHECK_VAL("#4 rs2_rob_tag", rs2_rob_tag, 2);

        // #5 CYCLE
        // addi x2 x2 4: 00000000010000010000000100010011
        rob_entry_in = 4;
        if_id_packet_in = '{`TRUE, 32'b00000000010000010000000100010011, 16, 12};
        rs_alu_full = 0;
        rs_ld_st_full = 1;
        @(negedge clock)
        CHECK_VAL("#5 maptable_packet_rs1.rob_tag_val", maptable_packet_rs1.rob_tag_val, 4);
        CHECK_VAL("#5 maptable_packet_rs1.rob_tag_ready", maptable_packet_rs1.rob_tag_ready, 0);
        CHECK_VAL("#5 maptable_packet_rs2.rob_tag_val", maptable_packet_rs2.rob_tag_val, 0);
        CHECK_VAL("#5 maptable_packet_rs2.rob_tag_ready", maptable_packet_rs2.rob_tag_ready, 0);
        CHECK_VAL("#5 id_packet_out.inst", id_packet_out.inst, 32'b00000000010000010000000100010011);
        CHECK_VAL("#5 id_packet_out.wr_mem", id_packet_out.wr_mem, 0);
        CHECK_VAL("#5 id_packet_out.rd_mem", id_packet_out.rd_mem, 0);
        CHECK_VAL("#5 rs_alu_enable", rs_alu_enable, 1);
        CHECK_VAL("#5 rs_ld_st_enable", rs_ld_st_enable, 0);
        CHECK_VAL("#5 alloc_enable", alloc_enable, 1);
        CHECK_VAL("#5 alloc_wr_mem", alloc_wr_mem, 0);
        CHECK_VAL("#5 alloc_store_dep", alloc_store_dep, 0);
        // CHECK_VAL("#5 alloc_value_in", alloc_value_in, 0);
        CHECK_VAL("#5 alloc_value_in_valid", alloc_value_in_valid, 1);
        CHECK_VAL("#5 rs1_rob_tag", rs1_rob_tag, 4);
        CHECK_VAL("#5 rs2_rob_tag", rs2_rob_tag, 0);

        $display("Simulation finish!!");
        $finish;
    end

endmodule