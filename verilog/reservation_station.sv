`timescale 1ns/100ps

module ReservationStation #(parameter NO_WAIT_RS2 = 0)(
    // Input
    input clk,
    input reset,
    input CDB_DATA cdb, 
    input ID_EX_PACKET id_packet_out,
    input MAPTABLE_PACKET maptable_packet_rs1,
    input MAPTABLE_PACKET maptable_packet_rs2,
    input [`ROB_TAG_LEN-1:0] alloc_slot,
    input alloc_enable,
    input exec_stall,

    // Output
    output logic rs_full,
    output INSTR_READY_ENTRY ready_inst_entry
);

    INSTR_READY_ENTRY instr_ready_table [0:`RS_DEPTH-1];
    INSTR_READY_ENTRY sorted_instr_ready_table [0:`RS_DEPTH-1];
    logic [`BIRTHDAY_SIZE-1:0] max_birthday = 0;
    logic [`BIRTHDAY_SIZE-1:0] oldest_birthday;
    logic found_ready_instr;
    integer free_slot, ready_inst_index;
    generate
        for (genvar i = 0; i < `RS_DEPTH; i = i + 1) begin
            assign instr_ready_table[i].ready = instr_ready_table[i].rs1_ready & (instr_ready_table[i].rs2_ready | NO_WAIT_RS2);
        end
    endgenerate

    always_comb begin
        // find oldest ready instruction
        oldest_birthday = `MAX_BIRTHDAY;
        found_ready_instr = 0;
        ready_inst_index = 0;
        for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
            if (instr_ready_table[i].valid && instr_ready_table[i].ready && (instr_ready_table[i].birthday < oldest_birthday)) begin
                oldest_birthday = instr_ready_table[i].birthday;
                ready_inst_index = i;
                found_ready_instr = 1;                    
            end
        end
    end

    always_comb begin
        // find free slot            
        free_slot = `RS_DEPTH;
        for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
            if (~instr_ready_table[i].valid) begin
                free_slot = i;
                break;
            end
        end
        
        rs_full = free_slot == `RS_DEPTH;
    end

    assign ready_inst_entry = instr_ready_table[ready_inst_index];

    always_ff @(posedge clk) begin
        if (reset) begin
            for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
                instr_ready_table[i].valid <= 0;
                instr_ready_table[i].ready <= 0;
                instr_ready_table[i].rs1_ready <= 0;
                instr_ready_table[i].rs2_ready <= 0;
                instr_ready_table[i].birthday <= 0;
            end
        end
        else if (alloc_enable && !rs_full) begin
                instr_ready_table[free_slot].valid <= 1;
                instr_ready_table[free_slot].rs1_tag <= maptable_packet_rs1.rob_tag_val;
                instr_ready_table[free_slot].rs2_tag <= maptable_packet_rs2.rob_tag_val;
                instr_ready_table[free_slot].rd_tag <= alloc_slot;
                instr_ready_table[free_slot].rs1_value <= id_packet_out.rs1_value; // value from regfile
                instr_ready_table[free_slot].rs2_value <= id_packet_out.rs2_value; // value from regfile
                instr_ready_table[free_slot].rs1_ready <= (maptable_packet_rs1.rob_tag_val == 0) ? 1: maptable_packet_rs1.rob_tag_ready;
                instr_ready_table[free_slot].rs2_ready <= (maptable_packet_rs2.rob_tag_val == 0) ? 1: maptable_packet_rs2.rob_tag_ready;
                instr_ready_table[free_slot].birthday <= max_birthday; 
                instr_ready_table[free_slot].instr <= id_packet_out;

               max_birthday <= max_birthday + 1;
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
        
        // ready instruction was processed last cycle unless stalled
        if (found_ready_instr && !exec_stall) begin
            instr_ready_table[ready_inst_index].valid <= 0;
        end
    end
endmodule
