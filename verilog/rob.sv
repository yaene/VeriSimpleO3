`ifndef __ROB_V__
`define __ROB_V__

`timescale 1ns/100ps

`define EMPTY_ROB_ENTRY '{`FALSE, `FALSE, `ZERO_REG, `XLEN'b0, `XLEN'b0, `FALSE}

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
            output ROB_ENTRY head_entry           // the entry of the next instn to commit
            );
    parameter ROB_SIZE = 4; 
    
    logic [`ROB_TAG_LEN-1:0] head, next_head;
    logic [`ROB_TAG_LEN-1:0] tail, next_tail;

    ROB_ENTRY [ROB_SIZE-1:0] rob; // ROB entries

    logic clear_head;
    assign clear_head = rob[head].ready;

    always_ff @(posedge clock) begin
      if (reset) begin
        head = 0;
        tail = 0;
        for (int i = 0; i < ROB_SIZE; i++) begin
          rob[i] <= `EMPTY_ROB_ENTRY;
        end
      end
      else begin
        // read data from CDB
        if (cdb_data.valid) begin
          if (rob[cdb_data.rob_tag].wr_mem)
            rob[cdb_data.rob_tag].dest_addr <= cdb_data.value;
          else begin
            // todo yb: store value for any dependent stores and handle their readiness properly
            rob[cdb_data.rob_tag].value <= cdb_data.value;
            rob[cdb_data.rob_tag].ready <= `TRUE;
          end
        end
        // allocate ROB entry
        if (alloc_enable && !full)
          rob[tail] <= '{`TRUE, alloc_wr_mem, dest_reg,
                              `XLEN'b0, `XLEN'b0, `FALSE};
        // clear entry of committed instruction
        if (clear_head)
          rob[head] <= `EMPTY_ROB_ENTRY;

        // update head and tail
        head <= next_head; 
        tail <= next_tail;
      end
    end

    
      // if head is ready then we can remove it next cycle (will have committed)
    always_comb begin
      next_head = head;
      if (clear_head) begin
        if (head + 1 == ROB_SIZE) 
          next_head = 0;
        else
          next_head = head + 1;
      end
    end

    // if new slot was allocated move tail
    always_comb begin
      next_tail = tail;
      if (alloc_enable && !full) begin
        if (tail + 1 == ROB_SIZE) 
          next_tail = 0;
        else
          next_tail = tail + 1;
      end
    end

    assign full = rob[head].valid && tail == head;
    assign alloc_slot = tail;
    assign read_value = rob[read_rob_tag].value;
    assign head_entry = rob[head];

endmodule

`endif
