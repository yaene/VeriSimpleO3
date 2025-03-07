`timescale 1ns/100ps


  // Decode an instruction: given instruction bits IR produce the
  // appropriate datapath control signals.
  //
  // This is a *combinational* module (basically a PLA).
  //
module decoder(

	//input [31:0] inst,
	//input valid_inst_in,  // ignore inst when low, outputs will
	                      // reflect noop (except valid_inst)
	//see sys_defs.svh for definition
	input IF_ID_PACKET if_packet,
	
	output ALU_OPA_SELECT opa_select,
	output ALU_OPB_SELECT opb_select,
	output DEST_REG_SEL   dest_reg, // mux selects
	output ALU_FUNC       alu_func,
	output logic rd_mem, wr_mem, cond_branch, uncond_branch,
	output logic csr_op,    // used for CSR operations, we only used this as 
	                        //a cheap way to get the return code out
	output logic halt,      // non-zero on a halt
	output logic illegal,    // non-zero on an illegal instruction
	output logic valid_inst  // for counting valid instructions executed
	                        // and for making the fetch stage die on halts/
	                        // keeping track of when to allow the next
	                        // instruction out of fetch
	                        // 0 for HALT and illegal instructions (die on halt)

);

	INST inst;
	logic valid_inst_in;
	
	assign inst          = if_packet.inst;
	assign valid_inst_in = if_packet.valid;
	assign valid_inst    = valid_inst_in & ~illegal;
	
	always_comb begin
		// default control values:
		// - valid instructions must override these defaults as necessary.
		//	 opa_select, opb_select, and alu_func should be set explicitly.
		// - invalid instructions should clear valid_inst.
		// - These defaults are equivalent to a noop
		// * see sys_defs.vh for the constants used here
		opa_select = OPA_IS_RS1;
		opb_select = OPB_IS_RS2;
		alu_func = ALU_ADD;
		dest_reg = DEST_NONE;
		csr_op = `FALSE;
		rd_mem = `FALSE;
		wr_mem = `FALSE;
		cond_branch = `FALSE;
		uncond_branch = `FALSE;
		halt = `FALSE;
		illegal = `FALSE;
		if(valid_inst_in) begin
			casez (inst) 
				`RV32_LUI: begin
					dest_reg   = DEST_RD;
					opa_select = OPA_IS_ZERO;
					opb_select = OPB_IS_U_IMM;
				end
				`RV32_AUIPC: begin
					dest_reg   = DEST_RD;
					opa_select = OPA_IS_PC;
					opb_select = OPB_IS_U_IMM;
				end
				`RV32_JAL: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_PC;
					opb_select    = OPB_IS_J_IMM;
					uncond_branch = `TRUE;
				end
				`RV32_JALR: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_RS1;
					opb_select    = OPB_IS_I_IMM;
					uncond_branch = `TRUE;
				end
				`RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
				`RV32_BLTU, `RV32_BGEU: begin
					opa_select  = OPA_IS_PC;
					opb_select  = OPB_IS_B_IMM;
					cond_branch = `TRUE;
				end
				`RV32_LB, `RV32_LH, `RV32_LW,
				`RV32_LBU, `RV32_LHU: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					rd_mem     = `TRUE;
				end
				`RV32_SB, `RV32_SH, `RV32_SW: begin
					opb_select = OPB_IS_S_IMM;
					wr_mem     = `TRUE;
				end
				`RV32_ADDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_SLTI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLT;
				end
				`RV32_SLTIU: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLTU;
				end
				`RV32_ANDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_AND;
				end
				`RV32_ORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_OR;
				end
				`RV32_XORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_XOR;
				end
				`RV32_SLLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLL;
				end
				`RV32_SRLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRL;
				end
				`RV32_SRAI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRA;
				end
				`RV32_ADD: begin
					dest_reg   = DEST_RD;
				end
				`RV32_SUB: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SUB;
				end
				`RV32_SLT: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLT;
				end
				`RV32_SLTU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLTU;
				end
				`RV32_AND: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_AND;
				end
				`RV32_OR: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_OR;
				end
				`RV32_XOR: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_XOR;
				end
				`RV32_SLL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLL;
				end
				`RV32_SRL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SRL;
				end
				`RV32_SRA: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SRA;
				end
				`RV32_MUL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MUL;
				end
				`RV32_MULH: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULH;
				end
				`RV32_MULHSU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULHSU;
				end
				`RV32_MULHU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULHU;
				end
				`RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
					csr_op = `TRUE;
				end
				`WFI: begin
					halt = `TRUE;
				end
				default: illegal = `TRUE;

		endcase // casez (inst)
		end // if(valid_inst_in)
	end // always
endmodule // decoder

module is_stage (         
	input clock,              // system clock
	input reset,              // system reset
	// input from Commit stage
	input wb_reg_wr_en_out,    // COMMIT_PACKET.reg_wr_en_out
	input [4:0] wb_reg_wr_idx_out,  // COMMIT_PACKET.reg_wr_idx_out
	input [`XLEN-1:0] wb_reg_wr_data_out,  // COMMIT_PACKET.data_out
	// input from IF stage
	input IF_ID_PACKET if_id_packet_in,
	// input from Maptable
    input MAPTABLE_PACKET maptable_packet_rs1,
    input MAPTABLE_PACKET maptable_packet_rs2,
	// input from ROB
	input [`XLEN-1:0] rs1_read_rob_value,
	input [`XLEN-1:0] rs2_read_rob_value, 
	input branch_speculating,
	
	// output to hazard detection
	output is_ld_st_inst,
	output is_alu_inst,
	// output to RS + ROB + Maptable
	output ID_EX_PACKET id_packet_out, // rob.dest_reg, rs, maptable.inst
    // output to rob
    output alloc_wr_mem,                       // is new instruction a store?
    output [`XLEN-1:0] alloc_value_in,         // value to store if available during store issue
    output [`ROB_TAG_LEN-1:0] alloc_store_dep, // else ROB providing value of store
    output alloc_value_in_valid,               // whether store value is available at issue
	output [2:0] alloc_mem_size,
    output [`ROB_TAG_LEN-1:0] rs1_rob_tag,
	output [`ROB_TAG_LEN-1:0] rs2_rob_tag
);

	logic [`XLEN-1:0] regf_rs1_value;
	logic [`XLEN-1:0] regf_rs2_value;

    assign id_packet_out.inst = if_id_packet_in.inst;
    assign id_packet_out.NPC  = if_id_packet_in.NPC;
    assign id_packet_out.PC   = if_id_packet_in.PC;
	assign id_packet_out.predict_taken = if_id_packet_in.predict_taken;
	assign id_packet_out.predict_target_pc = if_id_packet_in.predict_target_pc;

	assign is_ld_st_inst = id_packet_out.rd_mem || id_packet_out.wr_mem;
	assign is_alu_inst = ~is_ld_st_inst && (id_packet_out.alu_func != ALU_MUL) && (id_packet_out.alu_func != ALU_MULH) && (id_packet_out.alu_func != ALU_MULHSU) && (id_packet_out.alu_func != ALU_MULHU);

    assign alloc_wr_mem = id_packet_out.wr_mem;
    assign alloc_value_in = id_packet_out.rs2_value;
    assign alloc_value_in_valid = (alloc_wr_mem && maptable_packet_rs2.rob_tag_val == 0);
    assign alloc_store_dep = maptable_packet_rs2.rob_tag_val;

	assign id_packet_out.spec = branch_speculating;

	DEST_REG_SEL dest_reg_select; 

	// Instantiate the register file used by this pipeline
	regfile regf_0 (
		.rda_idx(if_id_packet_in.inst.r.rs1),
		.rda_out(regf_rs1_value), 

		.rdb_idx(if_id_packet_in.inst.r.rs2),
		.rdb_out(regf_rs2_value),

		.wr_clk(clock),
		.wr_en(wb_reg_wr_en_out),
		.wr_idx(wb_reg_wr_idx_out),
		.wr_data(wb_reg_wr_data_out)
	);

	// instantiate the instruction decoder
	decoder decoder_0 (
		.if_packet(if_id_packet_in),	 
		// Outputs
		.opa_select(id_packet_out.opa_select),
		.opb_select(id_packet_out.opb_select),
		.alu_func(id_packet_out.alu_func),
		.dest_reg(dest_reg_select),
		.rd_mem(id_packet_out.rd_mem),
		.wr_mem(id_packet_out.wr_mem),
		.cond_branch(id_packet_out.cond_branch),
		.uncond_branch(id_packet_out.uncond_branch),
		.csr_op(id_packet_out.csr_op),
		.halt(id_packet_out.halt),
		.illegal(id_packet_out.illegal),
		.valid_inst(id_packet_out.valid)
	);

	// mux to generate dest_reg_idx based on
	// the dest_reg_select output from decoder
	always_comb begin
		case (dest_reg_select)
			DEST_RD:    id_packet_out.dest_reg_idx = if_id_packet_in.inst.r.rd;
			DEST_NONE:  id_packet_out.dest_reg_idx = `ZERO_REG;
			default:    id_packet_out.dest_reg_idx = `ZERO_REG; 
		endcase
	end

	assign rs1_rob_tag = maptable_packet_rs1.rob_tag_val;
	assign rs2_rob_tag = maptable_packet_rs2.rob_tag_val;

	assign id_packet_out.rs1_value = (maptable_packet_rs1.rob_tag_ready) ? rs1_read_rob_value : regf_rs1_value;
	assign id_packet_out.rs2_value = (maptable_packet_rs2.rob_tag_ready) ? rs2_read_rob_value : regf_rs2_value;

	assign alloc_mem_size = if_id_packet_in.inst.r.funct3;
   
endmodule // module id_stage
