`ifndef __BRANCH_RESOLUTION_V__
`define __BRANCH_RESOLUTION_V__

`timescale 1ns/100ps
module branch_resolution_unit ( 
    input clock,
    input reset,
    input branch_detected,
    input take_branch, // assume speculation is all branch_not_taken
    input valid_branch,

    output branch_pending,
    output logic kill,
    output logic resolve
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
                else state_next = READY;
            end
            PENDING:
                if (valid_branch) begin
                    if (take_branch) kill = `TRUE;
                    else resolve = `TRUE;
                    state_next = READY;
                end
                else state_next = PENDING;
        endcase
    end

    assign branch_pending = state;

endmodule

`endif // __BRANCH_RESOLUTION_V__