`ifndef __ROB_V__
`define __ROB_V__

`timescale 1ns/100ps

module rob (input clock,
            input reset,
            input alloc_enable,                    // should a new slot be allocated
            input alloc_wr_mem,                    // is new instruction a store?
            input [4:0] dest_reg,                  // dest register of new instruction
            input CDB_DATA cdb_data,               // data on CDB
            input [`ROB_TAG_LEN-1:0] read_rob_tag, // rob entry to read value from
            input [`XLEN-1:0] load_address,        // to check for any pending stores
            input [`ROB_TAG_LEN-1:0] load_rob_tag, // rob entry of load to check for pending stores

            output full,                           // is ROB full?
            output [`ROB_TAG_LEN-1:0] alloc_slot,  // rob tag of new instruction
            output [`XLEN-1:0] read_value,         // ROB[read_rob_tag].value
            output pending_stores,                 // whether there are any pending stores before load
            output [`XLEN-1:0] commit_value,       // value of instruction to be commited
            output commit_ready,                   // whether instruction at head of ROB is ready to commit
            output [4:0] commit_dest_reg,          // destination register of instruction at ROB head
            output [`XLEN-1:0] commit_dest_addr,    // destination address of store at ROB head
            output commit_wr_mem,                  // whether ROB head is a store
            );
    parameter ROB_SIZE = 4; // needs to be less than ROB_TAG_LEN bits can handle
    
    logic [`ROB_TAG_LEN-1:0] head;
    logic [`ROB_TAG_LEN-1:0] tail;

    logic [ROB_SIZE-1:0] ROB_ENTRY rob; // ROB entries


    
    
endmodule

`endif
