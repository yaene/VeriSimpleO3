`timescale 1ns/100ps


module branch_prediction_unit(
    input clock,
    input reset,
    input [`XLEN-1:0] PC,
    input [`XLEN-1:0] ex_PC,
    input ex_taken,
    input ex_branch,
    input [`XLEN-1:0] ex_target_PC,
    output predict_taken,
    output [`XLEN-1:0] predict_target_PC
);

logic [`PREDICTOR_COUNTER_ENTRIES-1:0][`PREDICTOR_COUNTER_BITS-1:0] counters;
logic [`PREDICTOR_COUNTER_BITS-1:0] count_next;
logic [`PREDICTOR_INDEX_BITS-1:0] bimod_index, bimod_ex_index;
logic [`BTB_INDEX_BITS-1:0] btb_index, btb_ex_index;

BTB_ENTRY [`BTB_ENTRIES-1:0] btb;
BTB_ENTRY btb_next;

assign bimod_index = PC[`PREDICTOR_INDEX_BITS-1:0];
assign bimod_ex_index = ex_PC[`PREDICTOR_INDEX_BITS-1:0];
assign btb_index = PC[`BTB_INDEX_BITS-1:0];
assign btb_ex_index = ex_PC[`BTB_INDEX_BITS-1:0];
// MSB of counter represents prediction
// if no target addr in BTB, fall through instead
assign predict_taken = counters[bimod_index][`PREDICTOR_COUNTER_BITS-1] & 
    btb[btb_index].valid & (btb[btb_index].tag == PC[`XLEN-1 -: `BTB_TAG_BITS]);
assign predict_target_PC = btb[btb_index].target_PC;


// saturating counter and BTB update
always_comb begin
    count_next = counters[bimod_ex_index];
    btb_next = btb[btb_ex_index];
    if (ex_taken) begin
        btb_next.valid = 1'b1;
        btb_next.tag = ex_PC[`XLEN-1 -: `BTB_TAG_BITS];
        btb_next.target_PC = ex_target_PC;
        if (count_next != '1) begin
            count_next += 1;
        end
    end
    else if(count_next != 0) begin
        count_next -= 1;
    end

end

always_ff @(posedge clock) begin
    if (reset)begin
        for (int i = 0; i < `PREDICTOR_COUNTER_ENTRIES; ++i) begin
            // intialize counters with all 1s
            counters[i] <= '1;
        end
        for (int i = 0; i < `BTB_ENTRIES; ++i) begin
            // intialize counters with all 1s
            btb[i] <= '0;
        end

    end
    if(ex_branch) begin
        counters[bimod_ex_index] <= count_next;
        btb[btb_ex_index] <= btb_next;
    end
end
endmodule
