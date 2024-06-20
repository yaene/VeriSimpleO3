`timescale 1ns/100ps

module rob_testbench();
    parameter ROB_SIZE = 4;

    logic clock;
    logic reset;
    
    logic alloc_enable;                    // should a new slot be allocated
    logic alloc_wr_mem;                    // is new instruction a store?
    logic [`XLEN-1:0] alloc_store_value;               // value to be stored (if available)
    logic [`ROB_TAG_LEN-1:0] alloc_store_dep; // instn producing value to be stored              
    logic alloc_value_ready;
    logic [4:0] dest_reg;                  // dest register of new instruction
    CDB_DATA cdb_data;               // data on CDB
    logic [`ROB_TAG_LEN-1:0] read_rob_tag; // rob entry to read value from
    logic [`XLEN-1:0] load_address;        // to check for any pending stores
    logic [`ROB_TAG_LEN-1:0] load_rob_tag; // rob entry of load to check for pending stores
    
    logic full;                           // is ROB full?
    logic [`ROB_TAG_LEN-1:0] alloc_slot;  // rob tag of new instruction
    logic [`XLEN-1:0] read_value;         // ROB[read_rob_tag].value
    logic pending_stores;                 // whether there are any pending stores before load
    ROB_ENTRY head_entry;           // the entry of the next instn to commit
    logic head_ready;
    
    rob #(.ROB_SIZE(ROB_SIZE)) rob_1 (
    .clock (clock),
    .reset (reset),
    .alloc_enable (alloc_enable),
    .alloc_wr_mem (alloc_wr_mem),
    .alloc_store_value (alloc_store_value),
    .alloc_store_dep (alloc_store_dep),
    .alloc_value_ready (alloc_value_ready),
    .dest_reg (dest_reg),
    .cdb_data (cdb_data),
    .read_rob_tag (read_rob_tag),
    .load_address (load_address),
    .load_rob_tag (load_rob_tag),
    .full (full),
    .alloc_slot (alloc_slot),
    .read_value (read_value),
    .pending_stores (pending_stores),
    .head_entry (head_entry),
    .head_ready (head_ready)
    );

    always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end

    logic [`ROB_TAG_LEN-1:0] entry;

    task CHECK_VAL;
        input string desc;
		input [`XLEN-1:0] actual;
        input [`XLEN-1:0] expected;
        if( actual != expected ) begin
            $display("@@@ %s incorrect at time %4.0f", desc, $time);
            $display("@@@ expected: %h, actual: %h", expected, actual);
            $display("ENDING TESTBENCH : ERROR !");
            $finish;
        end
	endtask

    task TEST_HAPPY_FLOW;
        @(negedge clock)
        alloc_enable = 1;
        dest_reg = 3;
        entry = alloc_slot;

        @(negedge clock)
        CHECK_VAL("next slot", alloc_slot, 1);
        CHECK_VAL("allocated wrmem", head_entry.wr_mem, `FALSE);
        CHECK_VAL("allocated dest", head_entry.dest_reg, 3);
        CHECK_VAL("allocated ready", head_ready, `FALSE);
        cdb_data = '{`TRUE, entry, 5};
        alloc_enable = 0;

        @(negedge clock)
        CHECK_VAL("next slot", alloc_slot, 1);
        CHECK_VAL("head ready", head_ready, `TRUE);
        CHECK_VAL("head value", head_entry.value, 5);
        alloc_enable = 1;
        dest_reg = 1;

        @(negedge clock)
        CHECK_VAL("next slot", alloc_slot, 2);
        CHECK_VAL("head ready", head_ready, 0);
        CHECK_VAL("head dest", head_entry.dest_reg, 1);
        entry = alloc_slot;
        dest_reg = 2;

        @(negedge clock)
        CHECK_VAL("next slot", alloc_slot, 3);
        cdb_data = '{`TRUE, entry, 11};
        alloc_enable = 0;
        read_rob_tag = entry;

        @(negedge clock)
        CHECK_VAL("head ready", head_ready, 0);
        CHECK_VAL("prev value", read_value, 11);
        cdb_data = '{`TRUE, 1, 5};

        @(negedge clock)
        cdb_data = '{`FALSE, 1, 0};
        CHECK_VAL("head ready", head_ready, 1);
        CHECK_VAL("head value", head_entry.value, 5);

        @(negedge clock)
        CHECK_VAL("head ready", head_ready, 1);
        CHECK_VAL("head value", head_entry.value, 11);
        CHECK_VAL("head valid", head_entry.valid, 1);

        @(negedge clock)
        CHECK_VAL("head ready", head_ready, 0);
        CHECK_VAL("head valid", head_entry.valid, 0);

    endtask

    task TEST_FULL;
    
        logic [`ROB_TAG_LEN-1:0] head_tag;
        for (int i=1; i<=ROB_SIZE; i=i+1) begin
            @(negedge clock) 
            if(i==1) head_tag = alloc_slot;
            alloc_enable = 1;
            dest_reg = i;
            CHECK_VAL("not full", full, 0);
        end

        @(negedge clock)
        CHECK_VAL("full", full, 1);
        dest_reg = 10;
        cdb_data = '{`TRUE, head_tag, 11};

        @(negedge clock)
        CHECK_VAL("head ready", head_ready, 1);
        CHECK_VAL("head value", head_entry.value, 11);
        cdb_data = '{`FALSE, head_tag, 0};

        // check whether commit and add new entry can happen at the same time
        @(negedge clock)
        CHECK_VAL("full", full, 1);
        CHECK_VAL("head ready", head_ready, 0);
        CHECK_VAL("head dest", head_entry.dest_reg, 2);

        @(negedge clock)
        reset = 1;

        @(negedge clock)
        reset = 0;

    endtask

    initial begin
        $dumpvars;
        $monitor("Time:%4.0f, full:%b, read_rob: %d, read_value: %h, alloc_slot: %d",
            $time, full, read_rob_tag, read_value, alloc_slot);
    
        clock = 1;
        reset = 1;

        @(negedge clock)
        reset = 0;
        alloc_wr_mem = 0;
        dest_reg = `ZERO_REG;

        TEST_HAPPY_FLOW();
        TEST_FULL();

        $finish;

    end

endmodule
