module ReservationStation #(
    parameter RS_DEPTH = 4
) (
    input wire clk,
    input wire reset,
    input wire cdb,
    input ID_EX_PACKET id_packet_out,
    input MAPPED_REG_PACKET mapped_reg_packet,
    output wire rs_full,
    output ID_EX_PACKET ready_inst
);

    typedef struct packed {
        logic ready;
        logic [`XLEN-1:0] value;
    } REG_READY_ENTRY;

    typedef struct packed {
        logic valid;
        logic ready;
        logic birthday;
        ID_EX_PACKET inst;
    } INSTR_READY_ENTRY;

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
            
            //Check ready bit of reg from reg ready reg_ready_table


            //clear dest_reg ready bit 


            //add birthday to instr_ready_table & check ready bit of instr
            

            //send INSTR_READY_ENTRY to instruction queue 


        end
    end


endmodule