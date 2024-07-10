`timescale 1ns / 1ps

module commit_testbench();
    logic clock;
    logic reset;
    ROB_ENTRY head_entry;
    logic head_ready;

    COMMIT_PACKET  cmt_packet_out,

    initial begin
        clock = 1'b0;
        forever #5 clock = ~clock; // 10ns period
    end

    commit_stage cmt_1(
        .clock(clock),
        .reset (reset),
        .head_entry(head_entry),
        .head_ready(head_ready),
        // OUTPUT
        .cmt_packet_out(cmt_packet_out)
    );

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

    task TEST_WR_MEM;
        @(negedge clock) reset = 0;

        head_entry.valid = 1;
        head_entry.wr_mem = 1;
        head_entry.dest_reg = 5'b00001;
        @(negedge clock)


    endtask
    task 










    always #5 clk = ~clk;  // Generate clock signal
endmodule