`timescale 1ns/100ps

module wr_stage #(parameter FU_NUM=3) (
    // - FU_NUM: number of functional units WR has to arbitrate
    input clock,
    input reset,
    input CDB_DATA [FU_NUM-1:0] ex_packet_in, // result to put on CDB
    output CDB_DATA cdb,
    output logic [FU_NUM-1:0] written // one bit for each FU unit letting it know if its been chosen for WR or has to wait
);

always_comb begin
    logic cdb_busy = `FALSE;
    written = {FU_NUM{1'b0}};
    for (int i = 0; i < FU_NUM; ++i) begin
        if (~cdb_busy & ex_packet_in[i].valid) begin
            written[i] = `TRUE;
            cdb = ex_packet_in[i];
            cdb_busy = `TRUE;
        end
    end
    cdb.valid = cdb_busy;
end


endmodule
