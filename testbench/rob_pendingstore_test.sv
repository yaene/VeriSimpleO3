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

    task TEST_PENDING_STORES;
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
        // $monitor("Time:%4.0f, full:%b, read_rob: %d, read_value: %h, alloc_slot: %d",
        //     $time, full, read_rob_tag, read_value, alloc_slot);
        $monitor("TIME:%4.0f | ROB[0] READY: %b | ROB[1] READY: %b | ROB[2] READY: %b | ROB[3] READY: %b | PENDING STORE: %b", $time,
            (rob0.value_ready && rob0.address_ready),  (rob1.value_ready && rob1.address_ready),
            (rob2.value_ready && rob2.address_ready),  (rob3.value_ready && rob3.address_ready), pending_stores);

        clock = 1;
        reset = 1;

        @(negedge clock)
        reset = 0;
        alloc_wr_mem = 0;
        alloc_value_in_valid = 0;
        dest_reg = `ZERO_REG;

        TEST_PENDING_STORES();
        
        $display("Simulation Finish!!");
        $finish;

    end

endmodule
