`timescale 1ns/100ps

module ReservationStation (
    // Input
    input clk,
    input reset,
    input CDB_DATA cdb, 
    input ID_EX_PACKET id_packet_out,
    input MAPTABLE_PACKET maptable_packet_rs1,
    input MAPTABLE_PACKET maptable_packet_rs2,
    // input [`ROB_TAG_LEN-1:0] alloc_slot,
    input [3:0] alloc_slot,
    input enable,

    // Output
    output logic rs_full,
    output INSTR_READY_ENTRY ready_inst_entry
);

    INSTR_READY_ENTRY instr_ready_table [0:`RS_DEPTH-1];
    logic [`BIRTHDAY_SIZE-1:0] max_birthday = 0;
    logic [`BIRTHDAY_SIZE-1:0] oldest_birthday;
    logic found_ready_instr = 0;
    integer free_slot;

    always_comb begin
        if (id_packet_out.rd_mem) begin // Not ST/LD instruction
            for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
              instr_ready_table[i].ready = instr_ready_table[i].rs1_ready;
            end
        end
        else if (id_packet_out.wr_mem) begin // ST instruction
            for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
              instr_ready_table[i].ready = instr_ready_table[i].rs2_ready;
            end
        end
        else begin // LD instruction
            for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
              instr_ready_table[i].ready = instr_ready_table[i].rs1_ready & instr_ready_table[i].rs2_ready;
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rs_full <= 0;
            for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
                instr_ready_table[i].valid <= 0;
                instr_ready_table[i].ready <= 0;
                instr_ready_table[i].rs1_ready <= 0;
                instr_ready_table[i].rs2_ready <= 0;
                instr_ready_table[i].birthday <= `RS_DEPTH;
            end
        end
        else if (enable) begin
            // Dispatch
            free_slot = `RS_DEPTH;
            // Allocate slot
            for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
                if (~instr_ready_table[i].valid) begin
                    free_slot = i;
                    break;
                end
            end
            
            if (free_slot == `RS_DEPTH) begin
                rs_full <= 1;
            end 
            else begin
                rs_full <= 0;    

                instr_ready_table[free_slot].valid = 1;
                instr_ready_table[free_slot].rs1_tag = maptable_packet_rs1.rob_tag_val;
                instr_ready_table[free_slot].rs2_tag = maptable_packet_rs2.rob_tag_val;
                instr_ready_table[free_slot].rd_tag = alloc_slot;
                instr_ready_table[free_slot].rs1_value = id_packet_out.rs1_value; // value from regfile
                instr_ready_table[free_slot].rs2_value = id_packet_out.rs2_value; // value from regfile
                instr_ready_table[free_slot].rs1_ready = (instr_ready_table[free_slot].rs1_tag == 0)? 1: maptable_packet_rs1.rob_tag_ready;
                instr_ready_table[free_slot].rs2_ready = (instr_ready_table[free_slot].rs2_tag == 0)? 1: maptable_packet_rs2.rob_tag_ready;
                instr_ready_table[free_slot].birthday = max_birthday; 
                max_birthday = max_birthday + 1;
                instr_ready_table[free_slot].instr = id_packet_out;
            end
        end

        // Wait for ready value from CDB
        for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
            if (cdb.valid && instr_ready_table[i].valid && (instr_ready_table[i].rs1_tag == cdb.rob_tag)) begin
                instr_ready_table[i].rs1_value <= cdb.value;
                instr_ready_table[i].rs1_ready <= 1;
            end
            else if (cdb.valid && instr_ready_table[i].valid && (instr_ready_table[i].rs2_tag == cdb.rob_tag)) begin
                instr_ready_table[i].rs2_value <= cdb.value;
                instr_ready_table[i].rs2_ready <= 1;
            end
        end
        // Update ready instruction with the oldest birthday
        oldest_birthday = `RS_DEPTH;
        found_ready_instr = 0;
        ready_inst_entry = '0;
        for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
            if (instr_ready_table[i].valid && instr_ready_table[i].ready && (instr_ready_table[i].birthday < oldest_birthday)) begin
                oldest_birthday = instr_ready_table[i].birthday;
                found_ready_instr = 1;                    
            end
        end
        if (found_ready_instr) begin
            ready_inst_entry = instr_ready_table[oldest_birthday];
            instr_ready_table[oldest_birthday].valid <= 0;
        end
    end
endmodule