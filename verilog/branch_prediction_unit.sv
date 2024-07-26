`timescale 1ns/100ps


module branch_prediction_unit(
    input clock,
    input reset,
    input [`XLEN-1:0] pc,
    input [`XLEN-1:0] ex_pc,
    input ex_taken,
    input ex_branch,
    input [`XLEN-1:0] ex_target_pc,
    output predict_taken,
    output [`XLEN-1:0] predict_target_pc
);

logic [`PREDICTOR_ENTRIES-1:0][`PREDICTOR_COUNTER_BITS-1:0] counters_bimod,
         counters_gshare, counters_selector;
logic [`PREDICTOR_COUNTER_BITS-1:0] bimod_next, gshare_next, selector_next;
logic [`PREDICTOR_INDEX_BITS-1:0] pc_bits, ex_pc_bits;
logic [`PREDICTOR_INDEX_BITS-1:0] bimod_index, bimod_ex_index;
logic [`PREDICTOR_INDEX_BITS-1:0] gshare_index, gshare_ex_index;
logic [`PREDICTOR_INDEX_BITS-1:0] selector_index, selector_ex_index;
logic [`BTB_INDEX_BITS-1:0] btb_index, btb_ex_index;
logic bimod_prediction, gshare_prediction, prediction;
logic ex_bimod_prediction, ex_gshare_prediction;

BTB_ENTRY [`BTB_ENTRIES-1:0] btb;
BTB_ENTRY btb_next;
logic [`GLOBAL_HIST_BITS-1:0] global_hist;

assign pc_bits = pc[`PREDICTOR_INDEX_BITS-1:0];
assign ex_pc_bits = ex_pc[`PREDICTOR_INDEX_BITS-1:0];
assign bimod_index = pc_bits;
assign bimod_ex_index = ex_pc_bits;
assign gshare_index = pc_bits ^ global_hist;
assign gshare_ex_index = ex_pc_bits ^ global_hist;
assign selector_index = pc_bits;
assign selector_ex_index = ex_pc_bits;

assign btb_index = pc[`BTB_INDEX_BITS-1:0];
assign btb_ex_index = ex_pc[`BTB_INDEX_BITS-1:0];
// MSB of counter represents prediction
// if no target addr in BTB, fall through instead
assign bimod_prediction = counters_bimod[bimod_index][`PREDICTOR_COUNTER_BITS-1];
assign gshare_prediction = counters_gshare[gshare_index][`PREDICTOR_COUNTER_BITS-1];
assign ex_bimod_prediction = counters_bimod[bimod_ex_index][`PREDICTOR_COUNTER_BITS-1];
assign ex_gshare_prediction = counters_gshare[gshare_ex_index][`PREDICTOR_COUNTER_BITS-1];
assign prediction = counters_selector[selector_index][`PREDICTOR_COUNTER_BITS-1]
        ? bimod_prediction
        : gshare_prediction;
assign predict_taken =  prediction 
        & btb[btb_index].valid 
        & (btb[btb_index].tag == pc[`XLEN-1 -: `BTB_TAG_BITS]);
assign predict_target_pc = btb[btb_index].target_pc;

// saturating counter and BTB update
always_comb begin
    bimod_next = counters_bimod[bimod_ex_index];
    gshare_next = counters_gshare[gshare_ex_index];
    btb_next = btb[btb_ex_index];
    if (ex_taken) begin
        btb_next.valid = 1'b1;
        btb_next.tag = ex_pc[`XLEN-1 -: `BTB_TAG_BITS];
        btb_next.target_pc = ex_target_pc;
        if (bimod_next != '1) begin
            bimod_next += 1;
        end
        if (gshare_next != '1) begin
            gshare_next += 1;
        end
    end
    else begin 
        if(bimod_next != 0) begin
            bimod_next -= 1;
        end
        if(gshare_next != 0) begin
            gshare_next -= 1;
        end
    end
end

// selector update
always_comb begin
    selector_next = counters_selector[selector_ex_index];

    if(ex_gshare_prediction != ex_bimod_prediction) begin
        if (ex_taken == ex_bimod_prediction && selector_next != '1) begin
            selector_next += 1;
        end
        else if (ex_taken == ex_gshare_prediction && selector_next != 0) begin
            selector_next -= 1;
        end
    end
end

always_ff @(posedge clock) begin
    if (reset)begin
        for (int i = 0; i < `PREDICTOR_ENTRIES; ++i) begin
            // intialize predictors with all 1s
            // somehow '1 doesnt work here with vivado...
            counters_bimod[i] <= {`PREDICTOR_COUNTER_BITS{1'b1}};
            counters_gshare[i] <= {`PREDICTOR_COUNTER_BITS{1'b1}};
            counters_selector[i] <= {`PREDICTOR_COUNTER_BITS{1'b1}};
        end
        for (int i = 0; i < `BTB_ENTRIES; ++i) begin
            // initialize btb with all 0s
            btb[i] <= '0;
        end
        global_hist <= '1;

    end
    else if(ex_branch) begin
        counters_bimod[bimod_ex_index] <= bimod_next;
        counters_gshare[gshare_ex_index] <= gshare_next;
        counters_selector[selector_ex_index] <= selector_next;
        btb[btb_ex_index] <= btb_next;
        global_hist <= {ex_taken, global_hist[`GLOBAL_HIST_BITS-1:1]};
    end
end
endmodule
