`ifndef __LOAD_BUFFER_V__
`define __LOAD_BUFFER_V__

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
    output read_mem // going to read mem
)

    

endmodule

`endif
