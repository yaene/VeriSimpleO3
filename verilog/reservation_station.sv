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
    input enable,

    // Output
    output logic rs_full,
    output INSTR_READY_ENTRY ready_inst_entry
);

    INSTR_READY_ENTRY instr_ready_table [0:`RS_DEPTH-1];
    INSTR_READY_ENTRY sorted_instr_ready_table [0:`RS_DEPTH-1];
    logic [`BIRTHDAY_SIZE-1:0] max_birthday = 0;
    logic [`BIRTHDAY_SIZE-1:0] oldest_birthday;
    logic found_ready_instr = 0;
    logic smallest_birthday;
    integer free_slot;
//    assign instr_ready_table[0].ready = instr_ready_table[0].rs1_ready & (instr_ready_table[0].rs2_ready | NO_WAIT_RS2);
    generate
        for (genvar i = 0; i < `RS_DEPTH; i = i + 1) begin
            assign instr_ready_table[i].ready = instr_ready_table[i].rs1_ready & (instr_ready_table[i].rs2_ready | NO_WAIT_RS2);
        end
    endgenerate
    always_comb begin
        // Update ready instruction with the oldest birthday
        oldest_birthday = `MAX_BIRTHDAY;
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
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            rs_full = 0;
            for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
                instr_ready_table[i].valid = 0;
                instr_ready_table[i].ready = 0;
                instr_ready_table[i].rs1_ready = 0;
                instr_ready_table[i].rs2_ready = 0;
                instr_ready_table[i].birthday = `RS_DEPTH;
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
                rs_full = 1;
            end 
            else begin
                rs_full = 0;    

                instr_ready_table[free_slot].valid = 1;
                instr_ready_table[free_slot].rs1_tag = maptable_packet_rs1.rob_tag_val;
                instr_ready_table[free_slot].rs2_tag = maptable_packet_rs2.rob_tag_val;
                instr_ready_table[free_slot].rd_tag = alloc_slot;
                instr_ready_table[free_slot].rs1_value = id_packet_out.rs1_value; // value from regfile
                instr_ready_table[free_slot].rs2_value = id_packet_out.rs2_value; // value from regfile
                instr_ready_table[free_slot].rs1_ready = (instr_ready_table[free_slot].rs1_tag == 0)? 1: maptable_packet_rs1.rob_tag_ready;
                instr_ready_table[free_slot].rs2_ready = (instr_ready_table[free_slot].rs2_tag == 0)? 1: maptable_packet_rs2.rob_tag_ready;
                instr_ready_table[free_slot].birthday = max_birthday; 
                instr_ready_table[free_slot].instr = id_packet_out;

                //next instr will cause overflow
//                if (max_birthday == `MAX_BIRTHDAY) begin
//                    // found smallest birthday
//                    smallest_birthday = `MAX_BIRTHDAY;
//                    for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
//                        if (instr_ready_table[i].valid && instr_ready_table[i].birthday < smallest_birthday) begin
//                            smallest_birthday = instr_ready_table[i].birthday;
//                        end
//                    end
                    
//                    for (integer i = 0; i < `RS_DEPTH; i = i + 1) begin
//                        if (instr_ready_table[i].valid)
//                            instr_ready_table[i].birthday = instr_ready_table[i].birthday - smallest_birthday;
//                    end
//                end 
//                else begin
//                    max_birthday = max_birthday + 1;
//                end
                max_birthday = max_birthday + 1;
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
        
        if (found_ready_instr) begin
            instr_ready_table[oldest_birthday].valid = 0;
        end
    end
endmodule