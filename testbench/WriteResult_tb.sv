`timescale 1ns/100ps

module wr_stage_tb();

parameter FU_NUM = 3;

logic clock;
logic reset;
CDB_DATA [FU_NUM-1:0] ex_packet_in;
CDB_DATA cdb;
logic [FU_NUM-1:0] written; 

wr_stage #(.FU_NUM(FU_NUM)) wr_0 (
    .clock(clock), 
    .reset(reset), 
    .ex_packet_in(ex_packet_in),
    .cdb(cdb),
    .written(written)
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


initial begin
    // no valid inputs should have cdb invalid
    for(int i = 0; i < FU_NUM; ++i) begin
        ex_packet_in[i].valid = `FALSE;
    end
    #1;

    CHECK_VAL("cdb invalid if no ex packet", cdb.valid, `FALSE);
    CHECK_VAL("no written if no ex packet", written, 0);

    // first valid ex packet gets priority
    for(int i = 0; i < FU_NUM; ++i) begin
        ex_packet_in[i].valid = `TRUE;
        ex_packet_in[i].value = i+1;
    end

    #1;
    CHECK_VAL("cdb valid", cdb.valid, `TRUE);
    CHECK_VAL("cdb first value", cdb.value, 1);
    CHECK_VAL("first written", written, 1);

    // second can write if first is invalid

    ex_packet_in[0].valid = `FALSE;

    #1;

    CHECK_VAL("cdb valid", cdb.valid, `TRUE);
    CHECK_VAL("cdb second value", cdb.value, 2);
    CHECK_VAL("second written", written, 3'b010);

    $finish;
end

endmodule
