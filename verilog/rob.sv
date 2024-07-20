`ifndef __ROB_V__
`define __ROB_V__
`define DEBUG

`timescale 1ns/100ps

`define EMPTY_ROB_ENTRY '{`FALSE, 31'b0, `XLEN'b0, `FALSE, `ZERO_REG, `XLEN'b0, `XLEN'b0, `ROB_TAG_LEN'b0, 3'b0, `FALSE, `FALSE}

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

            input alloc_branch,
            input kill,
            
            output full,                              // is ROB full?
            output [`ROB_TAG_LEN-1:0] alloc_slot,     // rob tag of new instruction
            output [`XLEN-1:0] read_value_rs1,            // ROB[read_rob_tag_rs1].value
            output [`XLEN-1:0] read_value_rs2,            // ROB[read_rob_tag_rs2].value            
            output logic pending_stores,                    // whether there are any pending stores before load
            output [4:0] wr_dest_reg,                       // the destination register of the instruction writing back (for map table update)
            output [`ROB_TAG_LEN-1:0] wr_rob_tag,                        // the tag of the instruction writing back (for map table update)
            output wr_valid,                          // whether there is an instruction writing back
            output ROB_ENTRY head_entry,              // the entry of the next instn to commit
            output logic [`ROB_TAG_LEN-1:0] head,
            output head_ready
            `ifdef DEBUG
            ,output ROB_ENTRY rob0,
            output ROB_ENTRY rob1,
            output ROB_ENTRY rob2,
            output ROB_ENTRY rob3
            `endif
            );
    parameter ROB_SIZE = 4;
    
    logic [`ROB_TAG_LEN-1:0] next_head;
    logic [`ROB_TAG_LEN-1:0] tail, next_tail;
    logic clear_head, allocate_tail;
    logic [`XLEN-1:0] alloc_value;
    logic alloc_value_ready;
    logic [`ROB_TAG_LEN-1:0] tag_tracking; // to track tags
    logic [`ROB_TAG_LEN-1:0] branch_reg;
    logic [`ROB_TAG_LEN-1:0] tag_clearing;
    
    ROB_ENTRY [ROB_SIZE:1] rob; // ROB entries
    
    
    always_ff @(posedge clock) begin
        if (reset) begin
            head = 1;
            tail = 1;
            tag_tracking = 1;
            branch_reg = 0;
            for (int i = 1; i <= ROB_SIZE; i++) begin
                rob[i] <= `EMPTY_ROB_ENTRY;
            end
        end
        else begin
            // read data from CDB
            if (cdb_data.valid) begin
                if (rob[cdb_data.rob_tag].wr_mem) begin
                    rob[cdb_data.rob_tag].dest_addr     <= cdb_data.value;
                    rob[cdb_data.rob_tag].address_ready <= `TRUE;
                end
                else begin
                    // pass CDB data to corresponding ROB and any dep. stores
                    for (int i = 1; i <= ROB_SIZE; ++i) begin
                        if (i == cdb_data.rob_tag ||
                        (rob[i].wr_mem && rob[i].store_dep == cdb_data.rob_tag &&
                        !rob[i].value_ready)) begin
                        rob[i].value       <= cdb_data.value;
                        rob[i].value_ready <= `TRUE;
                    end
                end
            end
        end
        
        // allocate ROB entry
        if (allocate_tail) begin
            rob[tail] <= '{`TRUE, NPC, inst, alloc_wr_mem, dest_reg,
            `XLEN'b0, alloc_value, alloc_store_dep, alloc_mem_size,
            alloc_value_ready, ~alloc_wr_mem};

            if (alloc_branch) branch_reg <= tail;
            else branch_reg <= branch_reg;
        end
        
        // clear entry of committed instruction
        if (clear_head) begin
            rob[head] <= `EMPTY_ROB_ENTRY;
        end
        
        // update head and tail
        head <= next_head;
        tail <= next_tail;
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
        next_tail = tail;
        if (alloc_enable && !full) begin
            if (tail == ROB_SIZE)
                next_tail = 1;
            else
                next_tail = tail + 1;
        end
    end
    
    // forwarding from cdb to dependent store
    always_comb begin
        alloc_value       = alloc_value_in;
        alloc_value_ready = alloc_value_in_valid;
        if (alloc_wr_mem && cdb_data.valid
        && alloc_store_dep == cdb_data.rob_tag
        && !alloc_value_in_valid) begin
        alloc_value       = cdb_data.value;
        alloc_value_ready = `TRUE;
    end
    end

    // checking whether pending stores exist for the load instruction
    always_comb begin
        if (rob[load_rob_tag].valid && (load_rob_tag != head)) begin
            tag_tracking = (load_rob_tag == 1) ? ROB_SIZE  : load_rob_tag - 1;
            for (int i = 1; i < ROB_SIZE; i++) begin
                if (rob[tag_tracking].wr_mem && rob[tag_tracking].address_ready && (rob[tag_tracking].dest_addr == load_address)) begin
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

    always_comb begin
        if (kill) begin
            tag_clearing = (branch_reg == ROB_SIZE) ? 1 : branch_reg + 1;
            tail = branch_reg;
            for (int i = 1; i < ROB_SIZE; i++) begin
                if (tag_clearing != head) begin
                    rob[tag_clearing] = `EMPTY_ROB_ENTRY;
                    tag_clearing = (tag_clearing == ROB_SIZE) ? 1 : tag_clearing + 1;
                end
            end
        end
    end


    `ifdef DEBUG
    assign rob0 = rob[1];
    assign rob1 = rob[2];
    assign rob2 = rob[3];
    assign rob3 = rob[4];
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
    assign wr_valid = cdb_data.valid;
endmodule
    
`endif
