`timescale 1ns/100ps


module branch_prediction_unit(
    input clock,
    input reset,
    input [`XLEN-1:0] PC,
    input [`XLEN-1:0] ex_PC,
    input ex_taken,
    input ex_branch,
    output predict_taken
);

logic [`PREDICTOR_COUNTER_ENTRIES-1:0][`PREDICTOR_COUNTER_BITS-1:0] counters;
logic [`PREDICTOR_COUNTER_BITS-1:0] count_next;
logic [`PREDICTOR_INDEX_BITS-1:0] index, ex_index;


// MSB of counter represents prediction
assign predict_taken = counters[PC][`PREDICTOR_COUNTER_BITS-1];

// lower portion of PC is index
assign index = PC[`PREDICTOR_INDEX_BITS-1:0];
assign ex_index = ex_PC[`PREDICTOR_INDEX_BITS-1:0];

// saturating counter update
always_comb begin
    count_next = counters[ex_PC];
    if (ex_taken && count_next != '1) begin
        count_next += 1;
    end
    else if(!ex_taken && count_next != 0) begin
        count_next -= 1;
    end

end

always_ff @(posedge clock) begin
    if (reset)begin
        for (int i = 0; i < `PREDICTOR_COUNTER_ENTRIES; ++i) begin
            // intialize counters with all 1s
            counters[i] <= '1;
        end
    end
    if(ex_branch) begin
        counters[ex_PC] <= count_next;
    end
end
endmodule
