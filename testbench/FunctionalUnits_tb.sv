`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/04/2024 09:34:53 PM
// Design Name: 
// Module Name: testbench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module testbench;
    INSTR_READY_ENTRY alu_ready_inst_entry;
    CDB_DATA alu_cdb_output;
    logic take_branch;
    logic [`XLEN-1:0] branch_target_PC;

    INSTR_READY_ENTRY ld_st_ready_inst_entry;
    CDB_DATA store_result;
    LB_PACKET load_buffer_packet;

    alu_execution_unit alu_ex_unit(
        .ready_inst_entry(alu_ready_inst_entry),
        .alu_cdb_output(alu_cdb_output),
        .take_branch(take_branch),
        .branch_target_PC(branch_target_PC)
    );

    address_calculation_unit address_ex_unit(
        .ready_inst_entry(ld_st_ready_inst_entry),
        .store_result(store_result),
        .load_buffer_packet(load_buffer_packet)
    );

    initial begin
        alu_ready_inst_entry = '0;
        alu_cdb_output = '0;
        take_branch = 0;
        branch_target_PC = 0;

        ld_st_ready_inst_entry = '0;
        store_result = 0;
        load_buffer_packet = '0;

        #10; //alu, add 1+3=4
        alu_ready_inst_entry.instr.alu_func=ALU_ADD;
        alu_ready_inst_entry.instr.opa_select=OPA_IS_RS1;
        alu_ready_inst_entry.rs1_value = 1;
        alu_ready_inst_entry.rd_tag = 3;

        alu_ready_inst_entry.instr.opb_select=OPB_IS_RS2;
        alu_ready_inst_entry.rs2_value = 3;

        alu_ready_inst_entry.instr.uncond_branch = 0;
        alu_ready_inst_entry.instr.cond_branch = 0;
        #2;
        assert(alu_cdb_output.value == 4);
        assert(take_branch == 0);
        
        
        #50; //alu, sub 3-1=2
        alu_ready_inst_entry.instr.alu_func=ALU_SUB;
        alu_ready_inst_entry.instr.opa_select=OPA_IS_RS1;
        alu_ready_inst_entry.rs1_value = 3;
        alu_ready_inst_entry.rd_tag = 5;

        alu_ready_inst_entry.instr.opb_select=OPB_IS_RS2;
        alu_ready_inst_entry.rs2_value = 1;

        alu_ready_inst_entry.instr.uncond_branch = 0;
        alu_ready_inst_entry.instr.cond_branch = 0;
        #2;
        assert(alu_cdb_output.value == 2);
        assert(take_branch == 0);
        
        #50; //alu, beq,rs1=rs2, take_branch = 1
        alu_ready_inst_entry.rs1_value = 1;
        alu_ready_inst_entry.rs2_value = 1;
        alu_ready_inst_entry.instr.uncond_branch = 0;
        alu_ready_inst_entry.instr.cond_branch = 1;
        alu_ready_inst_entry.instr.inst.b.funct3 = 3'b000; //BEQ 
        alu_ready_inst_entry.instr.inst.b.of = 0;
        alu_ready_inst_entry.instr.inst.b.s = 0;
        alu_ready_inst_entry.instr.inst.b.f = 0;
        alu_ready_inst_entry.instr.inst.b.et = 4'b1000;
        alu_ready_inst_entry.instr.PC = 4;
        #2;
        assert(take_branch == 1);
        
        #50; //beq, rs1~=rs2
        alu_ready_inst_entry.rs1_value = 1;
        alu_ready_inst_entry.rs2_value = 2;
        alu_ready_inst_entry.instr.uncond_branch = 0;
        alu_ready_inst_entry.instr.cond_branch = 1;
        alu_ready_inst_entry.instr.inst.b.funct3 = 3'b000; //BEQ 
        alu_ready_inst_entry.instr.inst.b.of = 0;
        alu_ready_inst_entry.instr.inst.b.s = 0;
        alu_ready_inst_entry.instr.inst.b.f = 0;
        alu_ready_inst_entry.instr.inst.b.et = 4'b1000;
        ld_st_ready_inst_entry.instr.opa_select = OPA_IS_RS1;
        ld_st_ready_inst_entry.instr.opb_select = OPB_IS_B_IMM;
        alu_ready_inst_entry.instr.PC = 4;
        #2;
        assert(take_branch == 0);
        
        #50; //load, rs1=20, imm = 4, rd=9, PC_address = 16
        ld_st_ready_inst_entry.rs1_value = 8;
        ld_st_ready_inst_entry.instr.inst.i.imm = 8;
        ld_st_ready_inst_entry.rd_tag = 9;
        ld_st_ready_inst_entry.instr.opa_select = OPA_IS_RS1;
        ld_st_ready_inst_entry.instr.opb_select = OPB_IS_I_IMM;
        ld_st_ready_inst_entry.instr.alu_func=ALU_ADD;
        ld_st_ready_inst_entry.instr.rd_mem = 1;
        #2;
        assert(load_buffer_packet.valid == 1);
        assert(load_buffer_packet.address == 16);
        assert(load_buffer_packet.rd_tag == 9);
        assert(store_result.valid == 0);
        
        #50; //load, rs1 = 8, imm = 4, rs2 = 9
        ld_st_ready_inst_entry.rs1_value = 8;
        ld_st_ready_inst_entry.instr.inst.s.off = 0;
        ld_st_ready_inst_entry.instr.inst.s.set = 4;
        ld_st_ready_inst_entry.rd_tag = 9; //randomly set, just for commit
        ld_st_ready_inst_entry.instr.opa_select = OPA_IS_RS1;
        ld_st_ready_inst_entry.instr.opb_select = OPB_IS_S_IMM;
        ld_st_ready_inst_entry.instr.alu_func=ALU_ADD;
        ld_st_ready_inst_entry.instr.rd_mem = 0;
        ld_st_ready_inst_entry.instr.wr_mem = 1;
        #2;
        assert(store_result.valid == 1);
        assert(store_result.rob_tag == 9);
        assert(store_result.value == 12);
        assert(load_buffer_packet.valid == 0);
        #50 $finish;

    end

endmodule
