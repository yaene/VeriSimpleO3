
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
    ,output branch_determined
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
    assign alu_output.spec = ready_inst_entry.spec;

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
    assign branch_determined = ready_inst_entry.ready & alu_output.valid & (ready_inst_entry.instr.uncond_branch | ready_inst_entry.instr.cond_branch);

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
    assign store_result.spec = ready_inst_entry.spec;
    assign load_buffer_packet.spec = ready_inst_entry.spec;

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

module mult_stage #(parameter num_stages = 4)(
    input clock, reset, start, stall,
    input branch_determined, branch_misprediction,
    input [`XLEN-1:0] product_in, mplier_in, mcand_in,
    input INSTR_READY_ENTRY current_inst_entry_in, 

    output logic done,
    output logic [`XLEN-1:0] product_out, mplier_out, mcand_out,
    output INSTR_READY_ENTRY current_inst_entry_out 
);

    logic [`XLEN-1:0] prod_in_reg, partial_prod_reg;
    logic [`XLEN-1:0] partial_product, next_mplier, next_mcand;
    INSTR_READY_ENTRY current_inst_entry_reg; 

    parameter num_each = `XLEN / num_stages;
    assign product_out = prod_in_reg + partial_prod_reg;

    assign partial_product = mplier_in[(num_each-1):0] * mcand_in;

    assign next_mplier = {{num_each{1'b0}}, mplier_in[`XLEN-1:num_each]};
    assign next_mcand = {mcand_in[`XLEN-1-num_each:0], {num_each{1'b0}}};
    INSTR_READY_ENTRY next_inst_entry;

    always_comb begin
        next_inst_entry = current_inst_entry_in;

        if(branch_determined) begin
            next_inst_entry.spec = `FALSE;
        end
    end

    always_ff @(posedge clock or posedge reset) begin
        if (reset || (branch_misprediction && current_inst_entry_in.spec)) begin
            prod_in_reg      <= `XLEN'b0;
            partial_prod_reg <= `XLEN'b0;
            mplier_out       <= `XLEN'b0;
            mcand_out        <= `XLEN'b0;
            current_inst_entry_reg <= '0; 
            done             <= 1'b0;
        end 
        else if (!stall) begin
            prod_in_reg      <= product_in;
            partial_prod_reg <= partial_product;
            mplier_out       <= next_mplier;
            mcand_out        <= next_mcand;
            current_inst_entry_reg <= next_inst_entry; 
            done             <= start;
        end
    end
    // Output the current instr_entry_reg at this pipeline stage
    assign current_inst_entry_out = current_inst_entry_reg;

endmodule

module mult #(parameter num_stages = 4)(
    input clock, reset,
    input [`XLEN-1:0] mcand, mplier,
    input start,  
    input stall,  
    input branch_determined, branch_misprediction,
    input INSTR_READY_ENTRY current_inst_entry, 
    output [`XLEN-1:0] product,
    output done,
    output INSTR_READY_ENTRY current_done_inst_entry
);

    logic [`XLEN-1:0] mcand_out, mplier_out;
    logic [((num_stages-1)*`XLEN)-1:0] internal_products, internal_mcands, internal_mpliers;
    logic [(num_stages-2):0] internal_dones;
    INSTR_READY_ENTRY [(num_stages-2):0] internal_instr;

    mult_stage #(.num_stages(num_stages)) mstage [(num_stages-1):0] (
        .clock(clock),
        .reset(reset),
        .branch_determined(branch_determined),
        .branch_misprediction(branch_misprediction),
        .product_in({internal_products, `XLEN'h0}),
        .mplier_in({internal_mpliers, mplier}),
        .mcand_in({internal_mcands, mcand}),
        .start({internal_dones, start}),
        .stall(stall), 
        .product_out({product, internal_products}),
        .mplier_out({mplier_out, internal_mpliers}),
        .mcand_out({mcand_out, internal_mcands}),
        .done({done, internal_dones}),
        .current_inst_entry_in({internal_instr, current_inst_entry}),
        .current_inst_entry_out({current_done_inst_entry, internal_instr})
    );

endmodule

typedef enum { IDLE, BUSY } MULT_STATE;

module pipelined_multiplication_unit(
    input INSTR_READY_ENTRY ready_inst_entry, // output ready instruction entry from RS
    input clock,
    input reset,
    input previous_done, // indicates the previous multiplication is done
    input rs_mult_exec_stall, // mult is written in wr_stage
    input branch_determined,
    input branch_misprediction,

    output EX_WR_PACKET mult_output,
    output done, //indicates whether the multiplication is done
    output  [`XLEN-1:0] rs_mult_NPC_out,
    output  [31:0] rs_mult_IR_out,
    output rs_mult_valid_inst_out
);
    logic [`XLEN-1:0] opa, opb;
    ALU_FUNC func;
    logic start;
    logic [`XLEN-1:0] result;
    INSTR_READY_ENTRY current_inst_entry;
    INSTR_READY_ENTRY current_done_inst_entry;
    
    alu_info_extraction operands_extract(
        //Input
        .ready_inst_entry(ready_inst_entry),
        //Outputs
        .opa(opa),
        .opb(opb),
        .func(func)
    );
    
    mult mult_execute(
        //Inputs
        .clock(clock),
        .reset(reset),
        .branch_determined(branch_determined),
        .branch_misprediction(branch_misprediction),
        .mcand(opa),
        .mplier(opb),
        .start(start),
        .stall(rs_mult_exec_stall),
        .current_inst_entry(current_inst_entry),
        //Outputs
        .product(result),
        .current_done_inst_entry(current_done_inst_entry),
        .done(done)
    );
    assign start = ready_inst_entry.ready;
    assign current_inst_entry = ready_inst_entry;
    assign rs_mult_NPC_out        = current_inst_entry.instr.NPC ;
	assign rs_mult_IR_out         = current_inst_entry.instr.inst;
	assign rs_mult_valid_inst_out = current_inst_entry.instr.valid;
    always_comb begin
        if (~done) begin
            mult_output = '0;
       end
        else begin
            mult_output.valid = 1;
            mult_output.value = result;
            mult_output.rob_tag = current_done_inst_entry.rd_tag;
            mult_output.inst = current_done_inst_entry.instr.inst;
            mult_output.NPC = current_done_inst_entry.instr.NPC;
            mult_output.spec = current_done_inst_entry.spec;
        end
    end

endmodule
