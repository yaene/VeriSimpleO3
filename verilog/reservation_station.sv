module ReservationStation #(
    parameter RS_DEPTH = 4
) (
    // input
    input wire clk,
    input wire reset,
    input wire cdb, // common data bus
    input ID_EX_PACKET id_packet_out,
    input MAPPED_REG_PACKET mapped_reg_packet,

    // output
    output wire rs_full,
    output ID_EX_PACKET ready_inst
);

    
    REG_READY_ENTRY reg_ready_table [0:`XLEN-1];
    INSTR_READY_ENTRY instr_ready_table [0:RS_DEPTH-1];

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            rs_full <= 0;
            for(integer i = 0; i < `XLEN; i = i + 1) begin
                reg_ready_table[i].ready <= 0;
            end
            for(integer i = 0; i < RS_DEPTH; i = i + 1) begin
                instr_ready_table[i].valid <= 0;
                instr_ready_table[i].ready <= 0;
                instr_ready_table[i].birthday <= RS_DEPTH;
            end
        end else begin
            // Dispatch Phase Steps
            integer free_slot = -1;
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
            
                // 2. Read input ready bits
                logic src1_ready = reg_ready_table[mapped_reg_packet.phys_rs1].ready;
                logic src2_ready = reg_ready_table[mapped_reg_packet.phys_rs2].ready;

                // 3. Clear output ready bit
                reg_ready_table[mapped_reg_packet.new_phys_rd].ready <= 0;

                // 4. Write instruction to issue queue slot
                instr_ready_table[free_slot].valid <= 1;
                instr_ready_table[free_slot].ready <= src1_ready && src2_ready;
                instr_ready_table[free_slot].birthday <= 0; // Assuming birthday starts from 0
                instr_ready_table[free_slot].instr <= id_packet_out;

                // Increment birthdays of other instructions
                for (integer i = 0; i < RS_DEPTH; i = i + 1) begin
                    if (instr_ready_table[i].valid) begin
                        instr_ready_table[i].birthday <= instr_ready_table[i].birthday + 1;
                    end
                end
            end

            // Update ready instruction
            ready_inst = '0;
            for (integer i = 0; i < RS_DEPTH; i = i + 1) begin
                if (instr_ready_table[i].valid && instr_ready_table[i].ready) begin
                    ready_inst <= instr_ready_table[i].instr;
                    instr_ready_table[i].valid <= 0;
                    break;
                end
            end

            // Update ready table based on CDB
            for (integer i = 0; i < XLEN; i = i + 1) begin
                if (cdb[i]) begin
                    reg_ready_table[i].ready <= 1;
                end
            end
        end
    end


endmodule