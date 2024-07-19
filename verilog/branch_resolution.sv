`ifndef __BRANCH_RESOLUTION_V__
`define __BRANCH_RESOLUTION_V__

`timescale 1ns/100ps
module branch_resolution_unit ( 
    input clock,
    input reset,
    // Treat one branch only, IF will stall for second branch until the first is resolved
    //input [`ROB_TAG_LEN-1:0] branch_rob_tag,
    input branch_detected,
    input take_branch, // assume speculation is all branch_not_taken
    input valid_branch,
    // input maptable snapshot

    output busy,
    output logic kill,
    output logic resolve
    // output maptable recovery
);

    parameter READY = 1'b0, PENDING = 1'b1;
    logic state, state_next;

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            state <= READY;
            kill <= `FALSE;
            resolve <= `FALSE;
        end
        else begin
            state <= state_next;
        end
    end

    always_comb begin
        case (state)
            READY: begin
                kill = `FALSE;
                resolve = `FALSE;
                if (branch_detected) begin
                    state_next = PENDING;
                end
            end
            PENDING:
                if (valid_branch) begin
                    if (take_branch) kill = `TRUE;
                    else resolve = `TRUE;
                end
                state_next = READY;
        endcase
    end

    assign busy = state;

endmodule

`endif // __BRANCH_RESOLUTION_V__