`timescale 1ns/100ps

module rob_testbench();
    parameter ROB_SIZE = 4;

    logic clock;
    logic reset;
    
    logic alloc_enable;                    // should a new slot be allocated
    logic alloc_wr_mem;                    // is new instruction a store?
    logic [`XLEN-1:0] alloc_value_in;               // value to be stored (if available)
    logic [`ROB_TAG_LEN-1:0] alloc_store_dep; // instn producing value to be stored              
    logic alloc_value_in_valid;
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
    ROB_ENTRY rob0;
    ROB_ENTRY rob1;
    ROB_ENTRY rob2;
    ROB_ENTRY rob3;
    
    rob #(.ROB_SIZE(ROB_SIZE)) rob_1 (
    .clock (clock),
    .reset (reset),
    .alloc_enable (alloc_enable),
    .alloc_wr_mem (alloc_wr_mem),
    .alloc_value_in (alloc_value_in),
    .alloc_store_dep (alloc_store_dep),
    .alloc_value_in_valid (alloc_value_in_valid),
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
    .head_ready (head_ready),
    .rob0(rob0),
    .rob1(rob1),
    .rob2(rob2),
    .rob3(rob3)
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
        if( actual !== expected ) begin
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
        alloc_enable = 0;
        reset = 1;

        @(negedge clock)
        reset = 0;

    endtask

    task TEST_VALUE_TO_DEPENDENT_STORES;
        logic [`ROB_TAG_LEN-1:0] head_tag;
        logic [`ROB_TAG_LEN-1:0] alloc_tag;

        // check store ready when value already from issue
        @(negedge clock)
        alloc_enable = 1;
        dest_reg = 3;
        alloc_value_in_valid = 1;
        alloc_value_in = 10;
        alloc_wr_mem = 1;
        head_tag = alloc_slot;

        @(negedge clock)
        alloc_enable = 0;
        cdb_data = '{`TRUE, head_tag, 11};

        @(negedge clock)
        CHECK_VAL("store ready", head_ready, 1);
        CHECK_VAL("store address", head_entry.dest_addr, 11);
        CHECK_VAL("store value", head_entry.value, 10);
        cdb_data = '{`FALSE, head_tag, 11};

        // check value from other instruction is forwared to store
        @(negedge clock)
        alloc_enable = 1;
        alloc_value_in_valid = 0;
        alloc_wr_mem = 0;
        head_tag = alloc_slot;

        @(negedge clock)
        alloc_wr_mem = 1;
        alloc_store_dep = head_tag; // store dep on prev inst
        alloc_tag = alloc_slot;

        @(negedge clock)
        CHECK_VAL("prev not ready", head_ready, 0);
        // what happens if data gets announced on CDB in same cycle as new store allocated?
        cdb_data = '{`TRUE, head_tag, 5};

        @(negedge clock)
        alloc_enable = 0;
        CHECK_VAL("prev ready", head_ready, 1);
        cdb_data = '{`FALSE, alloc_tag, 0}; 
        
        @(negedge clock)
        cdb_data = '{`TRUE, alloc_tag, 2}; // store address on CDB
        CHECK_VAL("store head", head_entry.wr_mem, 1);
        CHECK_VAL("store not ready", head_ready, 0);

        @(negedge clock)
        cdb_data = '{`FALSE, alloc_tag, 0}; // store address on CDB
        CHECK_VAL("store head", head_entry.wr_mem, 1);
        CHECK_VAL("store ready", head_ready, 1);

        @(negedge clock)
        CHECK_VAL("store head", head_entry.wr_mem, 1);
        CHECK_VAL("second store also got value", head_entry.value_ready, 1);

    endtask

    task TEST_PENDING_STORES;
        $monitor("TIME:%4.0f | ROB[0] READY: %b | ROB[1] READY: %b | ROB[2] READY: %b | ROB[3] READY: %b | PENDING STORE: %b", $time,
            (rob0.value_ready && rob0.address_ready),  (rob1.value_ready && rob1.address_ready),
            (rob2.value_ready && rob2.address_ready),  (rob3.value_ready && rob3.address_ready), pending_stores);

        $display("PENDING STORE TEST!!");
        @(negedge clock)
        alloc_enable = 1;
        dest_reg = 3;

        @(negedge clock)
        CHECK_VAL("1. allocated wrmem", head_entry.wr_mem, `FALSE);
        CHECK_VAL("1. address ready", head_entry.dest_reg, 3);
        CHECK_VAL("1. allocated ready", head_ready, `FALSE);
        CHECK_VAL("1. Pending Stores?", pending_stores, `FALSE);
        alloc_enable = 0;

        @(negedge clock)
        CHECK_VAL("2. head ready", head_ready, `FALSE);
        CHECK_VAL("2. Pending Stores?", pending_stores, `FALSE);
        alloc_enable = 1;
        alloc_wr_mem = 1;
        alloc_store_dep = 0;

        @(negedge clock)
        CHECK_VAL("3. head ready", head_ready, `FALSE);
        CHECK_VAL("3. Pending Stores?", pending_stores, `FALSE);
        cdb_data = '{`TRUE, 1, 5};
        alloc_enable = 0;

        @(negedge clock)
        CHECK_VAL("4. head ready", head_ready, `FALSE);
        CHECK_VAL("4. Pending Stores?", pending_stores, `FALSE);
        alloc_enable = 1;
        alloc_wr_mem = 1;
        alloc_value_in = 3;
        alloc_value_in_valid = 1;

        @(negedge clock)
        CHECK_VAL("5. head ready", head_ready, `FALSE);
        CHECK_VAL("5. Pending Stores?", pending_stores, `FALSE);
        cdb_data = '{`TRUE, 2, 5};
        alloc_enable = 0;
        alloc_wr_mem = 0;

        @(negedge clock)
        CHECK_VAL("6. head ready", head_ready, `FALSE);
        CHECK_VAL("6. Pending Stores?", pending_stores, `FALSE);
        alloc_enable = 1;
        dest_reg = 2;

        @(negedge clock)
        CHECK_VAL("7. head ready", head_ready, `FALSE);
        CHECK_VAL("7. Pending Stores?", pending_stores, `FALSE);
        alloc_enable = 0;
        load_address = 5;
        load_rob_tag = 3;

        @(negedge clock)
        CHECK_VAL("8. head ready", head_ready, `FALSE);
        CHECK_VAL("8. Pending Stores?", pending_stores, `TRUE);
        cdb_data = '{`TRUE, 0, 4};

        @(negedge clock)
        CHECK_VAL("9. head ready", head_ready, `TRUE);
        CHECK_VAL("9. Pending Stores?", pending_stores, `TRUE);
        cdb_data = '{`TRUE, 3, 4};

        @(negedge clock)
        CHECK_VAL("10. head ready", head_ready, `TRUE);
        CHECK_VAL("10. Pending Stores?", pending_stores, `TRUE);
        alloc_enable = 1;
        alloc_wr_mem = 1;
        alloc_value_in = 2;
        alloc_value_in_valid = 1;

        @(negedge clock)
        CHECK_VAL("11. head ready", head_ready, `TRUE);
        CHECK_VAL("11. Pending Stores?", pending_stores, `TRUE);
        alloc_enable = 1;
        alloc_wr_mem = 1;
        alloc_value_in = 4;
        alloc_value_in_valid = 1;

        @(negedge clock)
        CHECK_VAL("12. head ready", head_ready, `TRUE);
        CHECK_VAL("12. Pending Stores?", pending_stores, `FALSE);
        alloc_enable = 1;
        alloc_wr_mem = 1;
        alloc_value_in = 3;
        alloc_value_in_valid = 1;

        @(negedge clock)
        CHECK_VAL("13. head ready", head_ready, `FALSE);
        CHECK_VAL("13. Pending Stores?", pending_stores, `FALSE);
        alloc_enable = 1;
        alloc_wr_mem = 1;
        alloc_value_in = 5;
        alloc_value_in_valid = 1;
        cdb_data = '{`TRUE, 0, 4};

        @(negedge clock)
        CHECK_VAL("14. head ready", head_ready, `TRUE);
        CHECK_VAL("14. Pending Stores?", pending_stores, `FALSE);
        alloc_enable = 0;
        alloc_wr_mem = 0;
        cdb_data = '{`TRUE, 1, 4};

        @(negedge clock)
        CHECK_VAL("15. head ready", head_ready, `TRUE);
        CHECK_VAL("15. Pending Stores?", pending_stores, `FALSE);
        alloc_enable = 1;
        dest_reg = 2;

        @(negedge clock)
        CHECK_VAL("16. head ready", head_ready, `FALSE);
        CHECK_VAL("16. Pending Stores?", pending_stores, `FALSE);
        alloc_enable = 0;

        @(negedge clock)
        CHECK_VAL("17. head ready", head_ready, `FALSE);
        CHECK_VAL("17. Pending Stores?", pending_stores, `FALSE);
        load_address = 4;
        load_rob_tag = 0;

        @(negedge clock)
        CHECK_VAL("18. head ready", head_ready, `FALSE);
        CHECK_VAL("18. Pending Stores?", pending_stores, `FALSE);
        cdb_data = '{`TRUE, 2, 4};

        @(negedge clock)
        CHECK_VAL("19. head ready", head_ready, `TRUE);
        CHECK_VAL("19. Pending Stores?", pending_stores, `TRUE);
        cdb_data = '{`TRUE, 3, 4};

        @(negedge clock)
        CHECK_VAL("20. head ready", head_ready, `TRUE);
        CHECK_VAL("20. Pending Stores?", pending_stores, `TRUE);

        @(negedge clock)
        CHECK_VAL("21. head ready", head_ready, `TRUE);
        CHECK_VAL("21. Pending Stores?", pending_stores, `FALSE);
        cdb_data = '{`TRUE, 0, 4};

        @(negedge clock)
        CHECK_VAL("22. head ready", head_ready, `FALSE);
        CHECK_VAL("22. Pending Stores?", pending_stores, `FALSE);

        @(negedge clock)
        CHECK_VAL("23. head ready", head_ready, `FALSE);
        CHECK_VAL("23. Pending Stores?", pending_stores, `FALSE);

        @(negedge clock)
        CHECK_VAL("24. head ready", head_ready, `FALSE);
        CHECK_VAL("24. Pending Stores?", pending_stores, `FALSE);

        $display("PENDING STORE TEST END!!");
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
        alloc_value_in_valid = 0;
        dest_reg = `ZERO_REG;

        TEST_HAPPY_FLOW();
        TEST_FULL();
        TEST_VALUE_TO_DEPENDENT_STORES();

        @(negedge clock)
        reset = 1;

        @(negedge clock)
        reset = 0;
        alloc_wr_mem = 0;
        alloc_value_in_valid = 0;
        dest_reg = `ZERO_REG;
        TEST_PENDING_STORES();

        $finish;

    end

endmodule
