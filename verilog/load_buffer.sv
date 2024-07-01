`ifndef __LOAD_BUFFER_V__
`define __LOAD_BUFFER_V__

`define EMPTY_LB_PACKET '{`FALSE, `XLEN'b0, `ROB_TAG_LEN'b0} //, 5'b0}

module load_buffer (
    input clock,
    input reset,
    input LB_PACKET lb_packet_in,
    input pending_stores, // from ROB, whether there are pending stores
    input mem_busy, // from MEM, whether MEM is available

    output LB_PACKET lb_packet_out,
    output logic full, // to ACU, whether Load Buffer is available
    output [`XLEN-1:0] load_address, // to ROB
    output [`ROB_TAG_LEN-1:0] load_rob_tag, // to ROB
    output logic read_mem // going to read mem
)

    LB_PACKET lb_packet;

    always_ff @(posedge clock) begin
        if (reset) begin
            lb_packet <= `EMPTY_LB_PACKET;
            full <= `FALSE;
            read_mem <= `FALSE;
        end

        if (!full) begin
            if (lb_packet_in.valid) begin
                lb_packet <= lb_packet_in;
                full <= `TRUE;
            end
        end

        if (pending_stores) begin
            read_mem <= `FALSE;
        end
        else begin
            lb_packet.valid <= `TRUE;
            if (!mem_busy) begin
                read_mem <= `TRUE;
                full <= `FALSE;
            end
        end
    end

    assign load_address = lb_packet.address;
    assign load_rob_tag = lb_packet.rd_tag;
    assign lb_packet_out = lb_packet;

endmodule

`endif
