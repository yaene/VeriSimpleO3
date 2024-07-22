`timescale 1ns/100ps

module bpu_testbench();
    logic clock;
    logic reset;
    logic [`XLEN-1:0] pc;
    logic [`XLEN-1:0] ex_pc; 
    logic ex_taken;
    logic ex_branch;
    logic [`XLEN-1:0] ex_target_pc;
    logic predict_taken;
    logic [`XLEN-1:0] predict_target_pc;

    branch_prediction_unit bpu_0 (
        .clock (clock),
        .reset (reset),
        .pc(pc),
        .ex_pc(ex_pc),
        .ex_taken(ex_taken),
        .ex_branch(ex_branch),
        .ex_target_pc(ex_target_pc),
        .predict_taken(predict_taken),
        .predict_target_pc(predict_target_pc)
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
        $display("Simulation Start!");

        clock = 1'b1;
        reset = 1'b1;

        @(negedge clock)
        reset = 0;
        pc = 32'b1000000000000000;
        ex_pc = pc;
        ex_target_pc = 10;
        ex_taken = 0;
        ex_branch = 0;

        @(negedge clock)
        // BTB empty so fall through
        CHECK_VAL("#0 predict taken", predict_taken, 0);

        ex_branch = 1;
        ex_taken  = 1;
        @(negedge clock)
        // second time in BTB, predict taken
        // should saturate in positive direction
        CHECK_VAL("#1 predict taken", predict_taken, 1);
        CHECK_VAL("#1 predicted pc", predict_target_pc, ex_target_pc);
        pc = 0;
        ex_taken = 0;

        @(negedge clock)
        // BTB entry tag mismatch
        CHECK_VAL("#2 predict taken", predict_taken, 0);
        ex_taken = 1;
        ex_pc = 0;
        ex_target_pc = 5;

        @(negedge clock)
        CHECK_VAL("#3 predict taken", predict_taken, 1);
        CHECK_VAL("#3 predicted pc", predict_target_pc, 5);
        ex_taken = 0;

        @(negedge clock)
        CHECK_VAL("#4 predict taken", predict_taken, 1);
        CHECK_VAL("#4 predicted pc", predict_target_pc, 5);

        @(negedge clock)
        CHECK_VAL("#5 predict taken", predict_taken, 0);

        @(negedge clock)
        CHECK_VAL("#6 predict taken", predict_taken, 0);

        @(negedge clock)
        // should saturate in negative direction 
        CHECK_VAL("#7 predict taken", predict_taken, 0);

        $display("Simulation Success!");
        $finish;
    end
endmodule
