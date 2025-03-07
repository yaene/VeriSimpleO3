`ifndef __ROB_V__
`define __ROB_V__
`define DEBUG

`timescale 1ns/100ps

`define EMPTY_ROB_ENTRY '{`FALSE, 31'b0, `XLEN'b0, `FALSE, `ZERO_REG, `XLEN'b0, `XLEN'b0, `ROB_TAG_LEN'b0, 3'b0, `FALSE, `FALSE, `FALSE}

module rob (input clock,
            input reset,

            input alloc_enable,                       // should a new slot be allocated
            input INST inst,
            input [`XLEN-1:0] NPC,
            input alloc_wr_mem,                       // is new instruction a store?
            input [`XLEN-1:0] alloc_value_in,         // value to store if available during store issue
            input [`ROB_TAG_LEN-1:0] alloc_store_dep, // else ROB providing value of store
            input alloc_value_in_valid,               // whether store value is available at issue
            input [4:0] dest_reg,                     // dest register of new instruction
            input [2:0] alloc_mem_size,
            input [`ROB_TAG_LEN-1:0] read_rob_tag_rs1,    // rob entry to read value from
            input [`ROB_TAG_LEN-1:0] read_rob_tag_rs2, 

            input CDB_DATA cdb_data,                  // data on CDB
           
            input [`XLEN-1:0] load_address,           // to check for any pending stores
            input [`ROB_TAG_LEN-1:0] load_rob_tag,    // rob entry of load to check for pending stores

            input branch_speculating,
            input branch_determined,
            input branch_misprediction,
            
            output full,                              // is ROB full?
            output [`ROB_TAG_LEN-1:0] alloc_slot,     // rob tag of new instruction
            output [`XLEN-1:0] read_value_rs1,            // ROB[read_rob_tag_rs1].value
            output [`XLEN-1:0] read_value_rs2,            // ROB[read_rob_tag_rs2].value            
            output logic pending_stores,                    // whether there are any pending stores before load
            output [4:0] wr_dest_reg,                       // the destination register of the instruction writing back (for map table update)
            output [`ROB_TAG_LEN-1:0] wr_rob_tag,                        // the tag of the instruction writing back (for map table update)
            output wr_spec,
            output wr_valid,                          // whether there is an instruction writing back
            output ROB_ENTRY head_entry,              // the entry of the next instn to commit
            output logic [`ROB_TAG_LEN-1:0] head,
            output head_ready
            `ifdef DEBUG
            ,output ROB_ENTRY rob1,
            output ROB_ENTRY rob2,
            output ROB_ENTRY rob3,
            output ROB_ENTRY rob4,
            output [`ROB_TAG_LEN-1:0] branch_reg
            `endif
            );
    parameter ROB_SIZE = 4;
    
    logic [`ROB_TAG_LEN-1:0] next_head;
    logic [`ROB_TAG_LEN-1:0] tail, next_tail;
    logic clear_head, allocate_tail;
    logic [`XLEN-1:0] alloc_value;
    logic alloc_value_ready;
    logic [`ROB_TAG_LEN-1:0] tag_tracking; // to track tags
    logic [`ROB_TAG_LEN-1:0] tail_tracking;
    logic [`ROB_TAG_LEN-1:0] tag_clearing;
    
    ROB_ENTRY [ROB_SIZE:1] rob; // ROB entries
    ROB_ENTRY [ROB_SIZE:1] next_rob; // ROB entries
    
   always_comb begin 
    next_rob = rob;
        // read data from CDB
    if (cdb_data.valid) begin
        if (rob[cdb_data.rob_tag].wr_mem) begin
                next_rob[cdb_data.rob_tag].dest_addr     = cdb_data.value;
                next_rob[cdb_data.rob_tag].address_ready = `TRUE;
        end
        else begin
            // pass CDB data to corresponding ROB and any dep. stores
            for (int i = 1; i <= ROB_SIZE; ++i) begin
                if (i == cdb_data.rob_tag ||
                (rob[i].wr_mem && rob[i].store_dep == cdb_data.rob_tag &&
                !rob[i].value_ready)) begin
                    next_rob[i].value       = cdb_data.value;
                    next_rob[i].value_ready = `TRUE;
                end
            end
        end
    end

     // clear entry of committed instruction
    if (clear_head) begin
        next_rob[head] = `EMPTY_ROB_ENTRY;
    end

   
    // allocate ROB entry
    if (allocate_tail) begin
        next_rob[tail] = '{`TRUE, NPC, inst, alloc_wr_mem, dest_reg,
            `XLEN'b0, alloc_value, alloc_store_dep, alloc_mem_size,
            alloc_value_ready, ~alloc_wr_mem, branch_speculating};
    end
    
    if (branch_determined) begin
        if (branch_misprediction) begin
            for (int i = 1; i <= ROB_SIZE; i++) begin
                if (next_rob[i].spec) begin
                    next_rob[i] = `EMPTY_ROB_ENTRY;
                end
            end
        end
        else begin
            for (int i = 1; i <= ROB_SIZE + 1; i++) begin
                if (next_rob[i].spec) begin
                    next_rob[i].spec = `FALSE;
                end
            end
        end
    end
   end

    always_ff @(posedge clock) begin
        if (reset) begin
            head <= 1;
            tail <= 1;
            // branch_reg = 0;
            for (int i = 1; i <= ROB_SIZE; i++) begin
                rob[i] <= `EMPTY_ROB_ENTRY;
            end
        end
        else begin
       
        // update head and tail
        head <= next_head;
        tail <= next_tail;

        rob <= next_rob;
    end
    end
    
    
    // if head is ready then we can remove it next cycle (will have committed)
    always_comb begin
        next_head = head;
        if (head_ready) begin
            if (head == ROB_SIZE)
                next_head = 1;
            else
                next_head = head + 1;
        end
    end
    
    // if new slot was allocated move tail
    always_comb begin
        tail_tracking = next_head;
        for (int i = 0; i < ROB_SIZE; i++) begin
            if (next_rob[tail_tracking].valid) begin
                next_tail = tail_tracking;
                tail_tracking = (tail_tracking == ROB_SIZE) ? 1 : tail_tracking + 1;
            end
        end
        next_tail = tail_tracking;
     end
    
    // forwarding from cdb and rob to dependent store
    always_comb begin
        alloc_value       = alloc_value_in;
        alloc_value_ready = alloc_value_in_valid;
        if (alloc_wr_mem && !alloc_value_in_valid) begin 
            if (cdb_data.valid && alloc_store_dep == cdb_data.rob_tag) begin
                alloc_value       = cdb_data.value;
                alloc_value_ready = `TRUE;
            end
            else if (rob[alloc_store_dep].value_ready) begin
                alloc_value       = rob[alloc_store_dep].value;
                alloc_value_ready = `TRUE;
            end
        end
    end

    // checking whether pending stores exist for the load instruction
    always_comb begin
        if (rob[load_rob_tag].valid && (load_rob_tag != head)) begin
            tag_tracking = (load_rob_tag == 1) ? ROB_SIZE  : load_rob_tag - 1;
            for (int i = 1; i < ROB_SIZE; i++) begin
                if (rob[tag_tracking].wr_mem && (!rob[tag_tracking].address_ready || (rob[tag_tracking].address_ready && (rob[tag_tracking].dest_addr == load_address)))) begin
                    pending_stores = `TRUE;
                end
                if (tag_tracking != head) begin
                    tag_tracking = (tag_tracking == 1) ? ROB_SIZE : tag_tracking - 1;
                end
            end
        end
        else begin 
            pending_stores = `FALSE;
        end
    end


    `ifdef DEBUG
    assign rob1 = rob[1];
    assign rob2 = rob[2];
    assign rob3 = rob[3];
    assign rob4 = rob[4];
    `endif
    
    // address ready by default on non-stores
    assign head_ready = rob[head].value_ready && rob[head].address_ready;
    assign full       = rob[head].valid && tail == head && !head_ready;
    assign alloc_slot = tail;
    // values being written right now are considered ready in rob, forward from cdb
    assign read_value_rs1 = (cdb_data.valid && cdb_data.rob_tag == read_rob_tag_rs1) 
                ? cdb_data.value : rob[read_rob_tag_rs1].value;
    assign read_value_rs2 = (cdb_data.valid && cdb_data.rob_tag == read_rob_tag_rs2) 
                ? cdb_data.value : rob[read_rob_tag_rs2].value;

    assign head_entry = rob[head];
    // we allow for overwriting of just commited head by new entry
    assign clear_head    = head_ready && !(alloc_enable && tail == head);
    assign allocate_tail = alloc_enable && !full;

    // find dest reg for cdb data and repackage signals for map table
    assign wr_dest_reg = rob[cdb_data.rob_tag].dest_reg;
    assign wr_rob_tag = cdb_data.rob_tag;
    assign wr_spec = rob[cdb_data.rob_tag].spec;
    assign wr_valid = cdb_data.valid;
endmodule
    
`endif
