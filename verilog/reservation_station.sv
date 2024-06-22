module ReservationStation #(
    parameter RS_DEPTH = 4,
    parameter XLEN = 32
) (
    // Input
    input clk,
    input reset,
    input CDB_DATA cdb, // Common Data Bus
    input ID_EX_PACKET id_packet_out,
    input MAPPED_REG_PACKET mapped_reg_packet,

    // Output
    output rs_full,
    output ID_EX_PACKET ready_inst,
    output ex_st_ld_enable,
    output ex_alu_enable
);

    // Declare the ready tables
    REG_READY_ENTRY reg_ready_table [0:XLEN-1];
    INSTR_READY_ENTRY instr_ready_table [0:RS_DEPTH-1];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rs_full <= 0;
            ex_st_ld_enable <= 0;
            ex_alu_enable <= 0;
            for (integer i = 0; i < XLEN; i = i + 1) begin
                reg_ready_table[i].ready <= 0;
            end
            for (integer i = 0; i < RS_DEPTH; i = i + 1) begin
                instr_ready_table[i].valid <= 0;
                instr_ready_table[i].ready <= 0;
                instr_ready_table[i].rs1_ready <= 0;
                instr_ready_table[i].rs2_ready <= 0;
                instr_ready_table[i].rs1_tag <= 0;
                instr_ready_table[i].rs1_tag <= 0;
                instr_ready_table[i].birthday <= RS_DEPTH;
            end
        end else begin
            // Dispatch Phase Steps
            integer free_slot = -1;
            // 1. Allocate issue queue (IQ) slot
            for (integer i = 0; i < RS_DEPTH; i = i + 1) begin
                if (!instr_ready_table[i].valid) begin
                    free_slot = i;
                    break;
                end
            end

            if (free_slot == -1) begin
                // Issue queue is full
                rs_full <= 1;
            end else begin
                rs_full <= 0;
            
                // We need to store the tag, rs1_tag, and rs2_tag in case they are not avaiable currently, while mapped_reg_packet update at each clock rising edge (not stored)
                //logic src1_ready = reg_ready_table[mapped_reg_packet.phys_rs1].ready;
                //logic src2_ready = reg_ready_table[mapped_reg_packet.phys_rs2].ready;

                // 3. Clear output ready bit
                reg_ready_table[mapped_reg_packet.new_phys_rd].ready <= 0;

                // 4. Write information to issue queue slot
                instr_ready_table[free_slot].valid <= 1;
                instr_ready_table[free_slot].rs1_tag = mapped_reg_packet.phys_rs1;
                instr_ready_table[free_slot].rs2_tag = mapped_reg_packet.phys_rs2;
                instr_ready_table[free_slot].rs1_ready = reg_ready_table[instr_ready_table[free_slot].rs1_tag].ready
                instr_ready_table[free_slot].rs2_ready = reg_ready_table[instr_ready_table[free_slot].rs2_tag].ready
                instr_ready_table[free_slot].ready <= instr_ready_table[free_slot].rs1_ready && instr_ready_table[free_slot].rs2_ready;
                instr_ready_table[free_slot].birthday <= 0; // Assuming birthday starts from 0
                instr_ready_table[free_slot].instr <= id_packet_out;

                // Increment birthdays of other instructions
                for (integer i = 0; i < RS_DEPTH; i = i + 1) begin
                    if (instr_ready_table[i].valid) begin
                        instr_ready_table[i].birthday <= instr_ready_table[i].birthday + 1;
                    end
                end
            end

            // Update ready table based on CDB
            for (integer i = 0; i < XLEN; i = i + 1) begin
                if (cdb.valid && (reg_ready_table[i].value == cdb.rob_tag))
                    reg_ready_table[i].ready <= 1;
                end
            end
            for (integer i = 0; i < RS_DEPTH; i = i + 1) begin
                if (cdb.valid && (instr_ready_table[i].rs1_tag == cdb.rob_tag)) begin
                    instr_ready_table[i].rs1_value <= cdb.value;
                    instr_ready_table[i].rs2_ready <= 1;
                end
                else if (cdb.valid && (instr_ready_table[i].rs2_tag == cdb.rob_tag)) begin
                    instr_ready_table[i].rs2_value <= cdb.value;
                    instr_ready_table[i].rs2_ready <= 1;
                end
                //if (cdb[i]) begin
                //    reg_ready_table[i].ready <= 1;
                //end
            //end
            
            // Update ready instruction
            ready_inst = '0;
            for (integer i = 0; i < RS_DEPTH; i = i + 1) begin
                if (instr_ready_table[i].valid && instr_ready_table[i].ready) begin
                    ready_inst <= instr_ready_table[i].instr;
                    instr_ready_table[i].valid <= 0;
                    if (ready_inst.wr_mem || ready_inst.rd_mem) begin //store/load instruction
                        ex_st_ld_enable <= 1;
                        ex_alu_enable <= 0;
                    end
                    else begin
                        ex_st_ld_enable <= 0;
                        ex_alu_enable <= 1;
                    end
                    // Mark the destination register as ready
                    // For the ready bit of the destination register, I suppose this should listen from the CDB? since we are not sure when this would be ready
                    // reg_ready_table[instr_ready_table[i].instr.dest].ready <= 1;
                    break;
                end
            end
        end
    end
endmodule
