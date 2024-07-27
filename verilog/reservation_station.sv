`timescale 1ns/100ps

module ReservationStation #(parameter NO_WAIT_RS2 = 0, parameter RS_DEPTH = 4)(
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

    INSTR_READY_ENTRY [RS_DEPTH-1:0] instr_ready_table;
    INSTR_READY_ENTRY new_entry;
    logic [`BIRTHDAY_SIZE-1:0] max_birthday = 0;
    logic [`BIRTHDAY_SIZE-1:0] oldest_birthday;
    logic found_ready_instr;
    integer free_slot, ready_inst_index;

    always_comb begin
        for (int i = 0; i < RS_DEPTH; i = i + 1) begin
            instr_ready_table[i].ready = 0;
            if (instr_ready_table[i].rs1_ready & (instr_ready_table[i].rs2_ready | NO_WAIT_RS2)) begin
                instr_ready_table[i].ready = 1;
            end 
            // consider ready if value is currently on CDB (forwarding)
            else if(cdb.valid) begin
                if(instr_ready_table[i].rs1_ready && instr_ready_table[i].rs2_tag == cdb.rob_tag) begin
                    instr_ready_table[i].ready = 1;
                end
                else if(instr_ready_table[i].rs2_ready && instr_ready_table[i].rs1_tag == cdb.rob_tag) begin
                    instr_ready_table[i].ready = 1;
                end
                else if (instr_ready_table[i].rs1_tag == cdb.rob_tag && instr_ready_table[i].rs2_tag == cdb.rob_tag) begin
                    instr_ready_table[i].ready = 1;
                end
            end
        end
    end

    always_comb begin
        ready_inst_entry = instr_ready_table[ready_inst_index];
        // forwarding
        if (!ready_inst_entry.rs1_ready) begin
            ready_inst_entry.rs1_value = cdb.value;
        end
        if (!ready_inst_entry.rs2_ready) begin
            ready_inst_entry.rs2_value = cdb.value;
        end
    end

    always_comb begin
        // find oldest ready instruction
        oldest_birthday = `MAX_BIRTHDAY;
        found_ready_instr = 0;
        ready_inst_index = 0;
        for (integer i = 0; i < RS_DEPTH; i = i + 1) begin
            if (instr_ready_table[i].valid && instr_ready_table[i].ready && (instr_ready_table[i].birthday <= oldest_birthday)) begin
                oldest_birthday = instr_ready_table[i].birthday;
                ready_inst_index = i;
                found_ready_instr = 1;                    
            end
        end
    end

    always_comb begin
        // find free slot            
        free_slot = RS_DEPTH;
        for (integer i = 0; i < RS_DEPTH; i = i + 1) begin
            if (~instr_ready_table[i].valid) begin
                free_slot = i;
                break;
            end
        end
        
        rs_full = (free_slot == RS_DEPTH);
    end
    always_comb begin
        new_entry.valid = 1;
        new_entry.rs1_tag = maptable_packet_rs1.rob_tag_val;
        new_entry.rs2_tag = maptable_packet_rs2.rob_tag_val;
        new_entry.rd_tag = alloc_slot;
        new_entry.rs1_value = id_packet_out.rs1_value; // value from regfile
        new_entry.rs2_value = id_packet_out.rs2_value; // value from regfile
        new_entry.rs1_ready = (id_packet_out.opa_select != OPA_IS_RS1 && !id_packet_out.cond_branch) 
            || ((maptable_packet_rs1.rob_tag_val == 0) ? 1: maptable_packet_rs1.rob_tag_ready);
        new_entry.rs2_ready = (id_packet_out.opb_select != OPB_IS_RS2 && !id_packet_out.cond_branch)
            || ((maptable_packet_rs2.rob_tag_val == 0) ? 1: maptable_packet_rs2.rob_tag_ready);
        new_entry.birthday = max_birthday; 
        new_entry.instr = id_packet_out;
        new_entry.ready = new_entry.rs1_ready & (new_entry.rs2_ready | NO_WAIT_RS2);
    end


    always_ff @(posedge clk) begin
        if (reset) begin
            for (integer i = 0; i < RS_DEPTH; i = i + 1) begin
                instr_ready_table[i] <= '0;
            end
        end
        else begin
            for (integer i = 0; i < RS_DEPTH; i = i + 1) begin
                if (i == free_slot && alloc_enable && !rs_full) begin
                    instr_ready_table[i] <= new_entry;
                    max_birthday <= max_birthday + 1;
                end
                else if (i == ready_inst_index && found_ready_instr && !exec_stall) begin
                    // ready instruction was processed last cycle unless stalled
                    instr_ready_table[i] <= '0;
                end
                 // Wait for ready value from CDB
                else if (cdb.valid && instr_ready_table[i].valid ) begin
                    if (!instr_ready_table[i].rs1_ready &&
                            instr_ready_table[i].rs1_tag == cdb.rob_tag) begin
                        instr_ready_table[i].rs1_value <= cdb.value;
                        instr_ready_table[i].rs1_ready <= 1;
                    end
                    if (!instr_ready_table[i].rs2_ready && 
                            instr_ready_table[i].rs2_tag == cdb.rob_tag) begin
                        instr_ready_table[i].rs2_value <= cdb.value;
                        instr_ready_table[i].rs2_ready <= 1;
                    end
                end
           
            end
        end
    end
endmodule
