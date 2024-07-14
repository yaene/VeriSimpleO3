/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline.v                                          //
//                                                                     //
//  Description :  Top-level module of the verisimple pipeline;        //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline togeather.                      //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __PIPELINE_V__
`define __PIPELINE_V__

`timescale 1ns/100ps

module pipeline (

	input         clock,                    // System clock
	input         reset,                    // System reset
	input [3:0]   mem2proc_response,        // Tag from memory about current request
	input [63:0]  mem2proc_data,            // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply
	
	output logic [1:0]  proc2mem_command,    // command sent to memory
	output logic [`XLEN-1:0] proc2mem_addr,      // Address sent to memory
	output logic [63:0] proc2mem_data,      // Data sent to memory
	output MEM_SIZE proc2mem_size,          // data size sent to memory

	output logic [3:0]  pipeline_completed_insts,
	output EXCEPTION_CODE   pipeline_error_status,
	output logic [4:0]  pipeline_commit_wr_idx,
	output logic [`XLEN-1:0] pipeline_commit_wr_data,
	output logic        pipeline_commit_wr_en,
	output logic [`XLEN-1:0] pipeline_commit_NPC,
	
	
	// testing hooks (these must be exported so we can test
	// the synthesized version) data is tested by looking at
	// the final values in memory
	
	
	// Outputs from IF-Stage 
	output logic [`XLEN-1:0] if_NPC_out,
	output logic [31:0] if_IR_out,
	output logic        if_valid_inst_out,
	
	// Outputs from IF/IS Pipeline Register
	output logic [`XLEN-1:0] if_is_NPC_out,
	output logic [31:0] if_is_IR_out,
	output logic        if_is_valid_inst_out,
	
	output logic [`XLEN-1:0] rs_alu_NPC_out,
	output logic [31:0] rs_alu_IR_out,
	output logic        rs_alu_valid_inst_out,
	
	output logic [`XLEN-1:0] rs_acu_NPC_out,
	output logic [31:0] rs_acu_IR_out,
	output logic        rs_acu_valid_inst_out,
	
	output logic [`XLEN-1:0] lb_NPC_out,
	output logic [31:0] lb_IR_out,
	output logic        lb_valid_inst_out,
	 
	output logic [`XLEN-1:0] ex_wr_NPC_out,
	output logic [31:0] ex_wr_IR_out,
	output logic        ex_wr_valid_inst_out,

	output logic [`XLEN-1:0] commit_NPC_out,
	output logic [31:0] commit_IR_out,
	output logic        commit_valid_inst_out

);

	// hazard detection unit outputs
    logic if_enable;
    logic if_is_enable;
    logic if_is_flush; // branch misprediction
    logic rob_enable;
    logic rs_ld_st_enable;
	logic rs_ld_exec_stall;
	logic rs_alu_enable;
    logic rs_alu_exec_stall;
    logic lb_exec_stall;
    logic alu_wr_enable;
    logic lb_wr_enable;
    logic acu_wr_enable;

	
	// Outputs from IF-Stage
	logic [`XLEN-1:0] proc2Imem_addr;
	logic [1:0] proc2Imem_command;
	IF_ID_PACKET if_packet;

	// Outputs from IF/IS Pipeline Register
	IF_ID_PACKET if_is_packet;

	// outputs from maptable
	MAPTABLE_PACKET maptable_packet_rs1, maptable_packet_rs2;

	// outputs from ROB
	logic rob_full;
    logic [`ROB_TAG_LEN-1:0] rob_alloc_slot; 
	logic [`XLEN-1:0] rob_read_value_rs1;       
	logic [`XLEN-1:0] rob_read_value_rs2;      
	logic pending_stores;                    
	logic [4:0] rob_wr_dest_reg;                       
	logic [`ROB_TAG_LEN-1:0] wr_rob_tag;              
	logic rob_wr_valid;                          
	ROB_ENTRY rob_head_entry;             
	logic [`ROB_TAG_LEN-1:0] rob_head;
	logic rob_head_ready;

	// Outputs from Issue stage
	ID_EX_PACKET is_packet;
	logic is_ld_st_inst;
	logic [`XLEN-1:0] rob_alloc_store_value; 
	logic [`ROB_TAG_LEN-1:0] rob_alloc_store_dep_inst;
	logic rob_alloc_wr_mem, is_hazard;
    logic [`XLEN-1:0] rob_alloc_value_in;
    logic rob_alloc_value_in_valid;
	logic [2:0] rob_alloc_mem_size;
    logic [`ROB_TAG_LEN-1:0] rob_alloc_store_dep, is_rs1_rob_tag,  is_rs2_rob_tag;

	// Outputs from Reservation Stations
	INSTR_READY_ENTRY rs_ld_st_out, rs_alu_out;
	logic rs_ld_st_full, rs_alu_full;
	
	// Outputs from EX-Stage
	EX_WR_PACKET alu_packet, acu_st_packet, lb_ex_packet;
	LB_PACKET acu_ld_packet;
	logic lb_read_mem, lb_full;
	logic [`ROB_TAG_LEN-1:0] lb_rob_tag;
	logic [`XLEN-1:0] lb_address;
	LB_PACKET lb_packet;
	logic ex_take_branch;
	logic [`XLEN-1:0]  ex_target_pc;


	// Outputs from EX/WR Pipeline Register
	EX_WR_PACKET acu_wr_packet, lb_wr_packet, alu_wr_packet;

	// outputs from WR-Stage
	CDB_DATA cdb_data;
	logic acu_written, alu_written, load_written;

	// Outputs from mem unit
	logic [`XLEN-1:0] proc2Dmem_addr;
	logic [`XLEN-1:0] proc2Dmem_data;
	logic [1:0]  proc2Dmem_command;
	MEM_SIZE proc2Dmem_size;
	logic mem_busy;
	
	// Outputs from Commit-Stage  (These loop back to the register file in issue)
	COMMIT_PACKET commit_packet;	

	assign pipeline_completed_insts = {3'b0, commit_packet.valid};
	assign pipeline_error_status =  
		commit_packet.inst == `WFI ? HALTED_ON_WFI :
									 NO_ERROR;
	
	assign pipeline_commit_wr_idx = commit_packet.reg_wr_idx_out;
	assign pipeline_commit_wr_data = commit_packet.data_out;
	assign pipeline_commit_wr_en = commit_packet.reg_wr_en_out;
	assign pipeline_commit_NPC = commit_packet.NPC;
	
	assign proc2mem_command =
	     (proc2Dmem_command == BUS_NONE) ? proc2Imem_command : proc2Dmem_command;
	assign proc2mem_addr =
	     (proc2Dmem_command == BUS_NONE) ? proc2Imem_addr : proc2Dmem_addr;
	//if it's an instruction, then load a double word (64 bits)
	assign proc2mem_size =
	     (proc2Dmem_command == BUS_NONE) ? DOUBLE : proc2Dmem_size;
	assign proc2mem_data = {32'b0, proc2Dmem_data};

//////////////////////////////////////////////////
//                                              //
//                  IF-Stage                    //
//                                              //
//////////////////////////////////////////////////

	//these are debug signals that are now included in the packet,
	//breaking them out to support the legacy debug modes
	assign if_NPC_out        = if_packet.NPC;
	assign if_IR_out         = if_packet.inst;
	assign if_valid_inst_out = if_packet.valid;
	
	if_stage if_stage_0 (
		// Inputs
		.clock (clock),
		.reset (reset),
		.if_enable(if_enable),
		.ex_take_branch(ex_take_branch),
		.ex_target_pc(ex_target_pc),
		.Imem2proc_data(mem2proc_data),
		.Imem2proc_response(mem2proc_response),
		.Imem2proc_data(mem2proc_data),
		
		// Outputs
		.proc2Imem_addr(proc2Imem_addr),
		.proc2Imem_command(proc2Imem_command),
		.if_packet_out(if_packet)
	);


//////////////////////////////////////////////////
//                                              //
//            IF/ID Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign if_is_NPC        = if_is_packet.NPC;
	assign if_is_IR         = if_is_packet.inst;
	assign if_is_valid_inst = if_is_packet.valid;
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset | if_is_flush) begin 
			if_is_packet.inst  <= `SD `NOP;
			if_is_packet.valid <= `SD `FALSE;
            if_is_packet.NPC   <= `SD 0;
            if_is_packet.PC    <= `SD 0;
		end else begin// if (reset)
			if (if_is_enable) begin
				if_is_packet <= `SD if_packet; 
			end // if (if_is_enable)	
		end
	end // always

//////////////////////////////////////////////////
//                                              //
//                     ROB                      //
//                                              //
//////////////////////////////////////////////////
	rob rob_0 (
		// inputs
		.clock(clock),
		.reset(reset),
		.alloc_enable(rob_enable),
		.inst(if_is_packet.inst),
		.NPC(if_is_packet.NPC),
		.alloc_wr_mem(rob_alloc_wr_mem),
		.alloc_value_in(rob_alloc_value_in),
		.alloc_store_dep(rob_alloc_store_dep_inst),
		.alloc_value_in_valid(rob_alloc_value_in_valid),
		.dest_reg(is_packet.dest_reg_idx),
		.alloc_mem_size(rob_alloc_mem_size),
		.read_rob_tag_rs1(maptable_packet_rs1.rob_tag_val),
		.read_rob_tag_rs2(maptable_packet_rs2.rob_tag_val),
		.cdb_data(cdb_data),
		.load_address(lb_address),
		.load_rob_tag(lb_rob_tag),
		// outputs 
		.full(rob_full),
		.alloc_slot(rob_alloc_slot),
		.read_value_rs1(rob_read_value_rs1),
		.read_value_rs2(rob_read_value_rs2),
		.pending_stores(pending_stores),
		.wr_dest_reg(rob_wr_dest_reg),
		.wr_rob_tag(wr_rob_tag),
		.wr_valid(rob_wr_valid),
		.head_entry(rob_head_entry),
		.head(rob_head),
		.head_ready(rob_head_ready)
	);

//////////////////////////////////////////////////
//                                              //
//             Hazard Detection                 //
//                                              //
//////////////////////////////////////////////////
logic is_branch; 
logic alu_branch;
assign is_branch = is_packet.cond_branch | is_packet.uncond_branch;
assign alu_branch = rs_alu_out.instr.cond_branch 
		| rs_alu_out.instr.uncond_branch;

hazard_detection_unit hdu_0 (
	// inputs
	.clock(clock),
	.reset(reset),
	.rs_ld_st_full(rs_ld_st_full),
	.rs_alu_full(rs_alu_full),
	.rob_full(rob_full),
	.lb_full(lb_full),
	.is_ld_st_inst(is_ld_st_inst),
	.is_valid_inst(is_packet.valid),
	.commit_wr_mem(commit_packet.wr_mem),
	.lb_read_mem(lb_read_mem),
	.is_branch(is_branch),
	.alu_branch(alu_branch),
	.ex_take_branch(ex_take_branch),
	.alu_wr_valid(alu_wr_packet.valid),
	.alu_wr_written(alu_written),
	.lb_wr_valid(lb_wr_packet.valid),
	.lb_wr_written(load_written),
	.acu_wr_valid(acu_wr_packet.valid),
	.acu_wr_written(acu_written),
	.acu_wr_mem(acu_st_packet.valid),
	.acu_rd_mem(acu_ld_packet.valid),

	// outputs
    .if_enable(if_enable),
    .if_is_enable(if_is_enable),
    .if_is_flush(if_is_flush), // branch misprediction
    .rob_enable(rob_enable),
    .rs_ld_st_enable(rs_ld_st_enable),
	.rs_ld_exec_stall(rs_ld_exec_stall),
	.rs_alu_enable(rs_alu_enable),
    .rs_alu_exec_stall(rs_alu_exec_stall),
    .lb_exec_stall(lb_exec_stall),
    .alu_wr_enable(alu_wr_enable),
    .lb_wr_enable(lb_wr_enable),
    .acu_wr_enable(acu_wr_enable)
);

   
//////////////////////////////////////////////////
//                                              //
//                  IS-Stage                    //
//                                              //
//////////////////////////////////////////////////
	assign if_is_NPC_out        = if_is_packet.NPC;
	assign if_is_IR_out         = if_is_packet.inst;
	assign if_is_valid_inst_out = if_is_packet.valid;
	
	maptable maptable_0 (
		//inputs
		.clock(clock),
		.reset(reset),
		.enable(rob_enable), // rob and maptable always update together
		.commit(commit_packet.valid),
		.rd_commit(commit_packet.reg_wr_idx_out),
		.rob_entry_commit(commit_packet.rob_tag),
		.inst(if_is_packet.inst),
		.rob_entry_in(rob_alloc_slot),
		.rd(is_packet.dest_reg_idx),
		.valid_wb(rob_wr_valid),
		.rd_wb(rob_wr_dest_reg),
		.rob_entry_wb(wr_rob_tag),
		//outputs
		.maptable_packet_rs1(maptable_packet_rs1),
		.maptable_packet_rs2(maptable_packet_rs2)
	);

	is_stage is_stage_0 (// Inputs
		.clock(clock),
		.reset(reset),
		.if_id_packet_in(if_is_packet),
		.wb_reg_wr_en_out   (commit_packet.reg_wr_en_out),
		.wb_reg_wr_idx_out  (commit_packet.reg_wr_idx_out),
		.wb_reg_wr_data_out (commit_packet.data_out),
		.maptable_packet_rs1(maptable_packet_rs1),
		.maptable_packet_rs2(maptable_packet_rs2),
		.rs1_read_rob_value(rob_read_value_rs1),
		.rs2_read_rob_value(rob_read_value_rs2),
		
		// Outputs
		.id_packet_out(is_packet),
		.is_ld_st_inst(is_ld_st_inst),
		.alloc_wr_mem(rob_alloc_wr_mem),
		.alloc_value_in(rob_alloc_value_in),
		.alloc_store_dep(rob_alloc_store_dep_inst),
		.alloc_value_in_valid(rob_alloc_value_in_valid),
		.alloc_mem_size(rob_alloc_mem_size),
		.rs1_rob_tag(is_rs1_rob_tag),
		.rs2_rob_tag(is_rs2_rob_tag)
	);

//////////////////////////////////////////////////
//                                              //
//           Reservation Stations               //
//                                              //
//////////////////////////////////////////////////


ReservationStation #(.NO_WAIT_RS2(1)) ld_st_rs  (
	//inputs
	.clk(clock),
	.reset(reset),
	.cdb(cdb_data),
	.id_packet_out(is_packet),
	.maptable_packet_rs1(maptable_packet_rs1),
	.maptable_packet_rs2(maptable_packet_rs2),
	.alloc_slot(rob_alloc_slot),
	.alloc_enable(rs_ld_st_enable),
	.exec_stall(rs_ld_exec_stall),

	// outputs
	.rs_full(rs_ld_st_full),
	.ready_inst_entry(rs_ld_st_out)
);

ReservationStation #(.NO_WAIT_RS2(0)) alu_rs  (
	//inputs
	.clk(clock),
	.reset(reset),
	.cdb(cdb_data),
	.id_packet_out(is_packet),
	.maptable_packet_rs1(maptable_packet_rs1),
	.maptable_packet_rs2(maptable_packet_rs2),
	.alloc_slot(rob_alloc_slot),
	.alloc_enable(rs_alu_enable),
	.exec_stall(rs_alu_exec_stall),

	// outputs
	.rs_full(rs_alu_full),
	.ready_inst_entry(rs_alu_out)
);


//////////////////////////////////////////////////
//                                              //
//                  EX-Stage                    //
//                                              //
//////////////////////////////////////////////////

	assign rs_alu_NPC_out        = rs_alu_out.instr.NPC;
	assign rs_alu_IR_out         = rs_alu_out.instr.inst;
	assign rs_alu_valid_inst_out = rs_alu_out.instr.valid;

alu_execution_unit alu_0 (
	// inputs
	.ready_inst_entry(rs_alu_out),
	// outputs
	.alu_output(alu_packet),
	.take_branch(ex_take_branch),
	.branch_target_PC(ex_target_pc)
);

	assign rs_acu_NPC_out        = rs_ld_st_out.instr.NPC;
	assign rs_acu_IR_out         = rs_ld_st_out.instr.inst;
	assign rs_acu_valid_inst_out = rs_ld_st_out.instr.valid;

address_calculation_unit acu_0 (
	// inputs
	.ready_inst_entry(rs_ld_st_out),
	// outputs
	.store_result(acu_st_packet),
	.load_buffer_packet(acu_ld_packet)
);

	assign lb_NPC_out        = lb_packet.NPC;
	assign lb_IR_out         = lb_packet.inst;
	assign lb_valid_inst_out = lb_packet.valid;

load_buffer load_buffer_0 (
	// inputs
	.clock(clock),
	.reset(reset),
	.lb_packet_in(acu_ld_packet),
	// all reasons when lb should not alloc are handled by lb_packet_in and full
	.alloc_enable(`TRUE), 
	.pending_stores(pending_stores),
	.lb_exec_stall(lb_exec_stall),
	// outputs
	.lb_packet_out(lb_packet),
	.full(lb_full),
	.load_address(lb_address),
	.load_rob_tag(lb_rob_tag),
	.read_mem(lb_read_mem)
);	

mem_stage mem_stage_0 (// Inputs
		.clock(clock),
		.reset(reset),
		.lb_packet_in(lb_packet),
		.read_mem(lb_read_mem),
		.cmt_packet_in(commit_packet),
		.Dmem2proc_data(mem2proc_data[`XLEN-1:0]),
		
		// Outputs
		.lb_ex_packet_out(lb_ex_packet),
		.proc2Dmem_command(proc2Dmem_command),
		.proc2Dmem_size(proc2Dmem_size),
		.proc2Dmem_addr(proc2Dmem_addr),
		.proc2Dmem_data(proc2Dmem_data)
	);



//////////////////////////////////////////////////
//                                              //
//           EX/WR Pipeline Registers           //
//                                              //
//////////////////////////////////////////////////
	
	always_ff @(posedge clock) begin
		if (reset) begin 
			acu_wr_packet <= '0;
            lb_wr_packet  <= '0;
            alu_wr_packet <= '0;
		end else begin// if (reset)
			if (acu_wr_enable) begin
				acu_wr_packet <= acu_st_packet; 
			end 
			if (lb_wr_enable) begin
				lb_wr_packet <= lb_ex_packet; 
			end 
			if (alu_wr_enable) begin
				alu_wr_packet <= alu_packet; 
			end 
		end
	end // always


//////////////////////////////////////////////////
//                                              //
//                  WR-Stage                    //
//                                              //
//////////////////////////////////////////////////
	assign ex_wr_valid_inst_out = cdb_data.valid;

	wr_stage wr_stage_0 (
		//inputs
		.clock(clock),
		.reset(reset),
		.ex_packet_in({acu_wr_packet,alu_wr_packet,lb_wr_packet}),
		// outputs
		.cdb(cdb_data),
		.written({acu_written, alu_written, load_written}),
		.wr_inst(ex_wr_IR_out),
		.wr_NPC(ex_wr_NPC_out)
	);

//////////////////////////////////////////////////
//                                              //
//              Commit-Stage                    //
//                                              //
//////////////////////////////////////////////////

	assign commit_NPC_out        = commit_packet.NPC;
	assign commit_IR_out         = commit_packet.inst;
	assign commit_valid_inst_out = commit_packet.valid;

	commit_stage commit_stage_0 (
		// inputs
		.clock(clock),
		.reset(reset),
		.head_entry(rob_head_entry),
		.head_ready(rob_head_ready),
		.commit_rob_tag(rob_head),
		// outputs
		.cmt_packet_out(commit_packet)
	);
endmodule  // module verisimple
`endif // __PIPELINE_V__
