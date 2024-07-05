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
    logic [FU_NUM-1:0] rs_full;
    logic stall_in;

    logic [FU_NUM-1:0] fu_option;
    ID_EX_PACKET id_packet_out;
    logic alloc_enable;
    logic alloc_wr_mem;
    logic [`XLEN-1:0] alloc_value_in;    
    logic [`ROB_TAG_LEN-1:0] alloc_store_dep;
    logic alloc_value_in_valid;
	logic [2:0] alloc_mem_size;
    logic [`ROB_TAG_LEN-1:0] rs1_rob_tag;
	logic [`ROB_TAG_LEN-1:0] rs2_rob_tag;
	logic stall_out;

    is_stage #(.FU_NUM(FU_NUM)) is_0 (
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
        .rs_full(rs_full),
        .stall_in(stall_in),

        .fu_option(fu_option),
        .id_packet_out(id_packet_out),
        .alloc_enable(alloc_enable),
        .alloc_wr_mem(alloc_wr_mem),
        .alloc_value_in(alloc_value_in),
        .alloc_store_dep(alloc_store_dep),
        .alloc_value_in_valid(alloc_value_in_valid),
        .alloc_mem_size(alloc_mem_size),
        .rs1_rob_tag(rs1_rob_tag),
        .rs2_rob_tag(rs2_rob_tag),
        .stall_out(stall_out)
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
        $finish;
    end

endmodule