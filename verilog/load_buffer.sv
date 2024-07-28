`ifndef __LOAD_BUFFER_V__
`define __LOAD_BUFFER_V__

`timescale 1ns/100ps

module load_buffer (
    input clock,
    input reset,
    input LB_PACKET lb_packet_in,
    input alloc_enable,
    input pending_stores, // from ROB, whether there are pending stores
    input lb_exec_stall, // from hazard detection unit
    input Dmem_ready, // from mem_stage
    input branch_determined,
    input branch_misprediction,

    output LB_PACKET lb_packet_out,
    output logic full, // to ACU, whether Load Buffer is available
    output [`XLEN-1:0] load_address, // to ROB
    output [`ROB_TAG_LEN-1:0] load_rob_tag, // to ROB
    output logic read_mem // going to read mem
);

    LB_PACKET lb_packet;

    always_ff @(posedge clock) begin
        if (reset) begin
            lb_packet <= '0;
            full <= `FALSE;
        end
        else begin
            if (!full) begin
                if (alloc_enable & lb_packet_in.valid) begin
                    lb_packet <= lb_packet_in;
                    full <= `TRUE;
                end
            end
            else begin
                if (Dmem_ready) begin
                    lb_packet <= '0;
                    full <= `FALSE;
                end
            end
        end
    end

    assign read_mem = lb_packet.valid && !pending_stores;

    assign load_address = lb_packet.address;
    assign load_rob_tag = lb_packet.rd_tag;

    always_comb begin
        lb_packet_out = lb_packet;
        if (branch_determined) begin
            if (branch_misprediction) begin
                lb_packet_out = '0;
            end
            else begin
                lb_packet_out.spec = `FALSE;
            end
        end
        // if (~read_mem || lb_exec_stall) begin
        //     // make sure that if we have no result available
        //     // it is not accidentally put on CDB
        //     lb_packet_out.valid = `FALSE;
        // end
    end
    

endmodule

`endif
