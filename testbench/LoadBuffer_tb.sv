`timescale 1ns/100ps

module load_buffer_testbench();
    logic clock;
    logic reset;

    LB_PACKET lb_packet_in;
    logic alloc_enable;
    logic pending_stores; // from ROB, whether there are pending stores
    logic mem_busy; // from MEM, whether MEM is available

    LB_PACKET lb_packet_out;
    logic full; // to ACU, whether Load Buffer is available
    logic [`XLEN-1:0] load_address; // to ROB
    logic [`ROB_TAG_LEN-1:0] load_rob_tag; // to ROB
    logic read_mem; // going to read mem

    load_buffer lb_0 (
        .clock (clock),
        .reset (reset),
        .lb_packet_in (lb_packet_in),
        .alloc_enable (alloc_enable),
        .pending_stores (pending_stores),
        .mem_busy (mem_busy),
        .lb_packet_out (lb_packet_out),
        .full (full),
        .load_address (load_address),
        .load_rob_tag (load_rob_tag),
        .read_mem (read_mem)
    );

    always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end

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

    initial begin
        $dumpvars;
        $display("Simulation Start!");

        clock = 1'b1;
        reset = 1'b1;

        @(negedge clock)
        reset = 1'b0;
        // lb_packet_in = '{1'b0, 32'b0, 5'b0};
        alloc_enable = 0;
        pending_stores = 1'b0;
        mem_busy = 1'b0;

        @(negedge clock)
        CHECK_VAL("#0 lb_packet_out.address", lb_packet_out.address, 0);
        CHECK_VAL("#0 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 0);
        CHECK_VAL("#0 full", full, 0);
        CHECK_VAL("#0 load_address", load_address, 0);
        CHECK_VAL("#0 load_rob_tag", load_rob_tag, 0);
        CHECK_VAL("#0 read_mem", read_mem, 0);
        alloc_enable = 1;
        lb_packet_in = '{`FALSE, 5, 1};

        @(negedge clock)
        CHECK_VAL("#1 lb_packet_out.address", lb_packet_out.address, 0);
        CHECK_VAL("#1 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 0);
        CHECK_VAL("#1 full", full, 0);
        CHECK_VAL("#1 load_address", load_address, 0);
        CHECK_VAL("#1 load_rob_tag", load_rob_tag, 0);
        CHECK_VAL("#1 read_mem", read_mem, 0);
        lb_packet_in = '{`TRUE, 5, 1};

        @(negedge clock)
        CHECK_VAL("#2 lb_packet_out.address", lb_packet_out.address, 5);
        CHECK_VAL("#2 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#2 full", full, 1);
        CHECK_VAL("#2 load_address", load_address, 5);
        CHECK_VAL("#2 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#2 read_mem", read_mem, 0);
        alloc_enable = 0;
        pending_stores = 1;

        @(negedge clock)
        CHECK_VAL("#3 lb_packet_out.address", lb_packet_out.address, 5);
        CHECK_VAL("#3 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#3 full", full, 1);
        CHECK_VAL("#3 load_address", load_address, 5);
        CHECK_VAL("#3 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#3 read_mem", read_mem, 0);
        alloc_enable = 1;
        lb_packet_in = '{`TRUE, 4, 2};

        @(negedge clock)
        CHECK_VAL("#4 lb_packet_out.address", lb_packet_out.address, 5);
        CHECK_VAL("#4 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#4 full", full, 1);
        CHECK_VAL("#4 load_address", load_address, 5);
        CHECK_VAL("#4 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#4 read_mem", read_mem, 0);
        pending_stores = 0;
        lb_packet_in = '{`FALSE, 3, 3};

        @(negedge clock)
        CHECK_VAL("#5 lb_packet_out.address", lb_packet_out.address, 5);
        CHECK_VAL("#5 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#5 full", full, 0);
        CHECK_VAL("#5 load_address", load_address, 5);
        CHECK_VAL("#5 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#5 read_mem", read_mem, 1);
        lb_packet_in = '{`TRUE, 2, 2};

        @(negedge clock)
        CHECK_VAL("#6 lb_packet_out.address", lb_packet_out.address, 2);
        CHECK_VAL("#6 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 2);
        CHECK_VAL("#6 full", full, 1);
        CHECK_VAL("#6 load_address", load_address, 2);
        CHECK_VAL("#6 load_rob_tag", load_rob_tag, 2);
        CHECK_VAL("#6 read_mem", read_mem, 0);
        alloc_enable = 0;

        @(negedge clock)
        CHECK_VAL("#7 lb_packet_out.address", lb_packet_out.address, 2);
        CHECK_VAL("#7 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 2);
        CHECK_VAL("#7 full", full, 0);
        CHECK_VAL("#7 load_address", load_address, 2);
        CHECK_VAL("#7 load_rob_tag", load_rob_tag, 2);
        CHECK_VAL("#7 read_mem", read_mem, 1);
        alloc_enable = 1;
        lb_packet_in = '{`TRUE, 4, 3};
        mem_busy = 1;

        @(negedge clock)
        CHECK_VAL("#8 lb_packet_out.address", lb_packet_out.address, 4);
        CHECK_VAL("#8 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 3);
        CHECK_VAL("#8 full", full, 1);
        CHECK_VAL("#8 load_address", load_address, 4);
        CHECK_VAL("#8 load_rob_tag", load_rob_tag, 3);
        CHECK_VAL("#8 read_mem", read_mem, 0);
        alloc_enable = 0;

        @(negedge clock)
        CHECK_VAL("#9 lb_packet_out.address", lb_packet_out.address, 4);
        CHECK_VAL("#9 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 3);
        CHECK_VAL("#9 full", full, 1);
        CHECK_VAL("#9 load_address", load_address, 4);
        CHECK_VAL("#9 load_rob_tag", load_rob_tag, 3);
        CHECK_VAL("#9 read_mem", read_mem, 0);
        mem_busy = 0;

        @(negedge clock)
        CHECK_VAL("#10 lb_packet_out.address", lb_packet_out.address, 4);
        CHECK_VAL("#10 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 3);
        CHECK_VAL("#10 full", full, 0);
        CHECK_VAL("#10 load_address", load_address, 4);
        CHECK_VAL("#10 load_rob_tag", load_rob_tag, 3);
        CHECK_VAL("#10 read_mem", read_mem, 1);
        alloc_enable = 1;
        lb_packet_in = '{`TRUE, 3, 1};
        mem_busy = 1;

        @(negedge clock)
        CHECK_VAL("#11 lb_packet_out.address", lb_packet_out.address, 3);
        CHECK_VAL("#11 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#11 full", full, 1);
        CHECK_VAL("#11 load_address", load_address, 3);
        CHECK_VAL("#11 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#11 read_mem", read_mem, 0);
        alloc_enable = 0;
        pending_stores = 1;
        
        @(negedge clock)
        CHECK_VAL("#12 lb_packet_out.address", lb_packet_out.address, 3);
        CHECK_VAL("#12 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#12 full", full, 1);
        CHECK_VAL("#12 load_address", load_address, 3);
        CHECK_VAL("#12 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#12 read_mem", read_mem, 0);

        @(negedge clock)
        CHECK_VAL("#13 lb_packet_out.address", lb_packet_out.address, 3);
        CHECK_VAL("#13 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#13 full", full, 1);
        CHECK_VAL("#13 load_address", load_address, 3);
        CHECK_VAL("#13 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#13 read_mem", read_mem, 0);
        mem_busy = 0;

        @(negedge clock)
        CHECK_VAL("#14 lb_packet_out.address", lb_packet_out.address, 3);
        CHECK_VAL("#14 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#14 full", full, 1);
        CHECK_VAL("#14 load_address", load_address, 3);
        CHECK_VAL("#14 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#14 read_mem", read_mem, 0);

        @(negedge clock)
        CHECK_VAL("#15 lb_packet_out.address", lb_packet_out.address, 3);
        CHECK_VAL("#15 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#15 full", full, 1);
        CHECK_VAL("#15 load_address", load_address, 3);
        CHECK_VAL("#15 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#15 read_mem", read_mem, 0);
        pending_stores = 0;

        @(negedge clock)
        CHECK_VAL("#16 lb_packet_out.address", lb_packet_out.address, 3);
        CHECK_VAL("#16 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#16 full", full, 0);
        CHECK_VAL("#16 load_address", load_address, 3);
        CHECK_VAL("#16 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#16 read_mem", read_mem, 1);

        @(negedge clock)
        CHECK_VAL("#17 lb_packet_out.address", lb_packet_out.address, 3);
        CHECK_VAL("#17 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#17 full", full, 0);
        CHECK_VAL("#17 load_address", load_address, 3);
        CHECK_VAL("#17 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#17 read_mem", read_mem, 0);

        @(negedge clock)
        CHECK_VAL("#18 lb_packet_out.address", lb_packet_out.address, 3);
        CHECK_VAL("#18 lb_packet_out.rd_tag", lb_packet_out.rd_tag, 1);
        CHECK_VAL("#18 full", full, 0);
        CHECK_VAL("#18 load_address", load_address, 3);
        CHECK_VAL("#18 load_rob_tag", load_rob_tag, 1);
        CHECK_VAL("#18 read_mem", read_mem, 0);

        $display("Simulation Success!");
        $finish;
    end
endmodule