`timescale 1ns/100ps

module bpu_testbench();
    logic clock;
    logic reset;
    logic [`XLEN-1:0] PC;
    logic [`XLEN-1:0] ex_PC; 
    logic ex_taken;
    logic ex_branch;
    logic [`XLEN-1:0] ex_target_PC;
    logic predict_taken;
    logic [`XLEN-1:0] predict_target_PC;

    branch_prediction_unit bpu_0 (
        .clock (clock),
        .reset (reset),
        .PC(PC),
        .ex_PC(ex_PC),
        .ex_taken(ex_taken),
        .ex_branch(ex_branch),
        .ex_target_PC(ex_target_PC),
        .predict_taken(predict_taken),
        .predict_target_PC(predict_target_PC)
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
        PC = 32'b1000000000000000;
        ex_PC = PC;
        ex_target_PC = 10;
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
        CHECK_VAL("#1 predicted PC", predict_target_PC, ex_target_PC);
        PC = 0;
        ex_taken = 0;

        @(negedge clock)
        // BTB entry tag mismatch
        CHECK_VAL("#2 predict taken", predict_taken, 0);
        ex_taken = 1;
        ex_PC = 0;
        ex_target_PC = 5;

        @(negedge clock)
        CHECK_VAL("#3 predict taken", predict_taken, 1);
        CHECK_VAL("#3 predicted PC", predict_target_PC, 5);
        ex_taken = 0;

        @(negedge clock)
        CHECK_VAL("#4 predict taken", predict_taken, 1);
        CHECK_VAL("#4 predicted PC", predict_target_PC, 5);

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
