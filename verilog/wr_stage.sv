`timescale 1ns/100ps

module wr_stage #(parameter FU_NUM=4) (
    // - FU_NUM: number of functional units WR has to arbitrate
    input clock,
    input reset,
    input EX_WR_PACKET [FU_NUM-1:0] ex_packet_in, // result to put on CDB
    output CDB_DATA cdb,
    output logic [FU_NUM-1:0] written, // one bit for each FU unit letting it know if its been chosen for WR or has to wait
    output INST wr_inst,
    output logic [`XLEN-1:0] wr_NPC
);

always_comb begin
    cdb.valid = `FALSE;
    written = {FU_NUM{1'b0}};
    wr_inst = 32'b0;
    wr_NPC = `XLEN'b0;
    for (int i = 0; i < FU_NUM; ++i) begin
        if (~cdb.valid & ex_packet_in[i].valid) begin
            written[i] = `TRUE;
            cdb.valid = `TRUE;
            cdb.value = ex_packet_in[i].value;
            cdb.rob_tag = ex_packet_in[i].rob_tag;
            wr_inst = ex_packet_in[i].inst;
            wr_NPC = ex_packet_in[i].NPC;
        end
    end
end


endmodule
