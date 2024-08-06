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

    LB_PACKET lb_packet, lb_packet_next;

    always_ff @(posedge clock) begin
        if (reset) begin
            lb_packet <= '0;
            full <= `FALSE;
        end
        else begin
            lb_packet <= lb_packet_next;
        end
    end

    assign read_mem = lb_packet.valid && !pending_stores;

    assign load_address = lb_packet.address;
    assign load_rob_tag = lb_packet.rd_tag;
    assign full = lb_packet.valid & ~Dmem_ready;

    always_comb begin
        lb_packet_next = lb_packet;
        if (~full & lb_packet_in.valid & alloc_enable) begin
            lb_packet_next = lb_packet_in;
        end else if(Dmem_ready) begin
            lb_packet_next = '0;
        end
        if (branch_determined) begin
            if (branch_misprediction & lb_packet_next.spec) begin
                lb_packet_next = '0;
            end
            else begin
                lb_packet_next.spec = `FALSE;
            end
        end

    end

    always_comb begin
        lb_packet_out = lb_packet;
        if (branch_determined) begin
            if (branch_misprediction & lb_packet.spec) begin
                lb_packet_out = '0;
            end
            else begin
                lb_packet_out.spec = `FALSE;
            end
        end
    end
    

endmodule

`endif
