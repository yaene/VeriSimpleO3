
module alu(
    input logic [`XLEN-1:0] opa,
    input logic [`XLEN-1:0] opb,
    ALU_FUNC     func,

    output logic [`XLEN-1:0] result
);
    wire signed [`XLEN-1:0] signed_opa, signed_opb;
    wire signed [2*`XLEN-1:0] signed_mul, mixed_mul;
    wire        [2*`XLEN-1:0] unsigned_mul;
    assign signed_opa = opa;
    assign signed_opb = opb;
    assign signed_mul = signed_opa * signed_opb;
    assign unsigned_mul = opa * opb;
    assign mixed_mul = signed_opa * opb;

    always_comb begin
        case (func)
            ALU_ADD:      result = opa + opb;
            ALU_SUB:      result = opa - opb;
            ALU_AND:      result = opa & opb;
            ALU_SLT:      result = signed_opa < signed_opb;
            ALU_SLTU:     result = opa < opb;
            ALU_OR:       result = opa | opb;
            ALU_XOR:      result = opa ^ opb;
            ALU_SRL:      result = opa >> opb[4:0];
            ALU_SLL:      result = opa << opb[4:0];
            ALU_SRA:      result = signed_opa >>> opb[4:0]; // arithmetic from logical shift
            ALU_MUL:      result = signed_mul[`XLEN-1:0];
            ALU_MULH:     result = signed_mul[2*`XLEN-1:`XLEN];
            ALU_MULHSU:   result = mixed_mul[2*`XLEN-1:`XLEN];
            ALU_MULHU:    result = unsigned_mul[2*`XLEN-1:`XLEN];

            default:      result = `XLEN'hfacebeec;  // here to prevent latches
        endcase
    end
endmodule // alu

module brcond(// Inputs
    input [`XLEN-1:0] rs1,    // Value to check against condition
    input [`XLEN-1:0] rs2,
    input  [2:0] func,  // Specifies which condition to check

    output logic cond    // 0/1 condition result (False/True)
);

    logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
    assign signed_rs1 = rs1;
    assign signed_rs2 = rs2;
    always_comb begin
        cond = 0;
        case (func)
            3'b000: cond = signed_rs1 == signed_rs2;  // BEQ
            3'b001: cond = signed_rs1 != signed_rs2;  // BNE
            3'b100: cond = signed_rs1 < signed_rs2;   // BLT
            3'b101: cond = signed_rs1 >= signed_rs2;  // BGE
            3'b110: cond = rs1 < rs2;                 // BLTU
            3'b111: cond = rs1 >= rs2;                // BGEU
        endcase
    end

endmodule // brcond

module alu_info_extraction(
    input INSTR_READY_ENTRY ready_inst_entry,

    output logic [`XLEN-1:0] opa,
    output logic [`XLEN-1:0] opb,
    output ALU_FUNC func
);
    ID_EX_PACKET id_ex_packet_in;
    assign id_ex_packet_in = ready_inst_entry.instr;
    assign func = id_ex_packet_in.alu_func;
    //
    // ALU opA mux
    //
    always_comb begin
        opa = `XLEN'hdeadfbac;
        case (id_ex_packet_in.opa_select)
            OPA_IS_RS1:  opa = ready_inst_entry.rs1_value;
            OPA_IS_NPC:  opa = id_ex_packet_in.NPC;
            OPA_IS_PC:   opa = id_ex_packet_in.PC;
            OPA_IS_ZERO: opa = 0;
        endcase
    end
     //
     // ALU opB mux
     //
    always_comb begin
        // Default value, Set only because the case isnt full.  If you see this
        // value on the output of the mux you have an invalid opb_select
        opb = `XLEN'hfacefeed;
        case (id_ex_packet_in.opb_select)
            OPB_IS_RS2:   opb = ready_inst_entry.rs2_value;
            OPB_IS_I_IMM: opb = `RV32_signext_Iimm(id_ex_packet_in.inst);
            OPB_IS_S_IMM: opb = `RV32_signext_Simm(id_ex_packet_in.inst);
            OPB_IS_B_IMM: opb = `RV32_signext_Bimm(id_ex_packet_in.inst);
            OPB_IS_U_IMM: opb = `RV32_signext_Uimm(id_ex_packet_in.inst);
            OPB_IS_J_IMM: opb = `RV32_signext_Jimm(id_ex_packet_in.inst);
        endcase 
    end
endmodule

module alu_execution_unit(
    input INSTR_READY_ENTRY ready_inst_entry, // output ready instruction entry from RS

    output EX_WR_PACKET alu_output, // CDB data output from ALU execution unit
    output logic [`XLEN-1:0] target_PC, // correct PC for branch misprediction
    output logic take_branch,
    output logic branch_misprediction // indicates whether branch was predicted to be taken
);
    logic brcond_result;
    logic [`XLEN-1:0] opa, opb;
    ALU_FUNC func;
    logic [`XLEN-1:0] result;
    logic [`XLEN-1:0] branch_target_PC;

    alu_info_extraction alu_extract(
        //Input
        .ready_inst_entry(ready_inst_entry),
        //Outputs
        .opa(opa),
        .opb(opb),
        .func(func)
    );

    alu alu_execute (
        // Inputs
        .opa(opa),
        .opb(opb),
        .func(func),
        // Output
        .result(result)
    );

    brcond brcond (// Inputs
        .rs1(ready_inst_entry.rs1_value), 
        .rs2(ready_inst_entry.rs2_value),
        .func(ready_inst_entry.instr.inst.b.funct3), // inst bits to determine check

        // Output
        .cond(brcond_result)
    );

    assign alu_output.inst = ready_inst_entry.instr.inst;
    assign alu_output.NPC = ready_inst_entry.instr.NPC;

     // ultimate "take branch" signal:
     // unconditional, or conditional and the condition is true
    assign take_branch = ready_inst_entry.ready & 
        (ready_inst_entry.instr.uncond_branch | 
        (ready_inst_entry.instr.cond_branch & brcond_result));
    assign branch_misprediction = ready_inst_entry.ready & 
        ((ready_inst_entry.instr.predict_taken ^ take_branch) |
         (take_branch & (ready_inst_entry.instr.predict_target_pc != branch_target_PC))
        );
    assign target_PC = take_branch ? branch_target_PC : alu_output.NPC;
    always_comb begin
        if (~ready_inst_entry.ready) begin
            alu_output.valid = 0;
            alu_output.value = 0;
            alu_output.rob_tag = 0;
            branch_target_PC = 0;
        end
        else if (take_branch) begin
            branch_target_PC = result;
            alu_output.valid = 1;
            alu_output.value = ready_inst_entry.instr.NPC;
            alu_output.rob_tag = ready_inst_entry.rd_tag;
        end
        else if (~ready_inst_entry.instr.uncond_branch && (~ready_inst_entry.instr.cond_branch)) begin
            branch_target_PC = 0; //no matter what, since not take_branch
            alu_output.valid = 1;
            alu_output.value = result;
            alu_output.rob_tag = ready_inst_entry.rd_tag;
        end
        else begin // not take branch, but branch instructions
            branch_target_PC = 0;
            alu_output.valid = 1;
            alu_output.value = 0;
            alu_output.rob_tag = ready_inst_entry.rd_tag;
        end

    end
endmodule // alu

module address_calculation_unit(
    input INSTR_READY_ENTRY ready_inst_entry, // output ready instruction entry from RS

    output EX_WR_PACKET store_result, // output address result for writing, for store instruction
    output LB_PACKET load_buffer_packet // output packet for load buffer usage
);
    logic [`XLEN-1:0] opa;
    logic [`XLEN-1:0] opb;
    ALU_FUNC func;
    logic [`XLEN-1:0] result;
    
    //Address calculation
    alu_info_extraction address_oprand_extract(
        //Input
        .ready_inst_entry(ready_inst_entry),
        //Outputs
        .opa(opa),
        .opb(opb),
        .func(func)
    );

    alu address_execute (
        // Inputs
        .opa(opa),
        .opb(opb),
        .func(func),
        // Output
        .result(result)
    );

    assign store_result.NPC = ready_inst_entry.instr.NPC;
    assign load_buffer_packet.NPC = ready_inst_entry.instr.NPC;
    assign store_result.inst = ready_inst_entry.instr.inst;
    assign load_buffer_packet.inst = ready_inst_entry.instr.inst;

    always_comb begin
        load_buffer_packet.address = result;
        load_buffer_packet.rd_tag = ready_inst_entry.rd_tag;
        load_buffer_packet.mem_size = ready_inst_entry.instr.inst.r.funct3;
        store_result.value = result;
        store_result.rob_tag = ready_inst_entry.rd_tag;
        if (ready_inst_entry.ready) begin
            if (ready_inst_entry.instr.rd_mem) begin //load
                store_result.valid = 0;
                load_buffer_packet.valid = 1;
                
            end
            else begin //store wr_mem = 1
                store_result.valid = 1;
                load_buffer_packet.valid = 0;
            end
        end else begin
            store_result.valid = 0;
            load_buffer_packet.valid = 0;
        end
    end

endmodule
