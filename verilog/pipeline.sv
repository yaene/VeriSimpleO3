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
	
	// Outputs from IF/ID Pipeline Register
	output logic [`XLEN-1:0] if_id_NPC,
	output logic [31:0] if_id_IR,
	output logic        if_id_valid_inst,
	
	
	// todo: provide proper values for pipeline printing
	// Outputs from ID/EX Pipeline Register
	output logic [`XLEN-1:0] id_ex_NPC,
	output logic [31:0] id_ex_IR,
	output logic        id_ex_valid_inst,
	
	
	// Outputs from EX/MEM Pipeline Register
	output logic [`XLEN-1:0] ex_mem_NPC,
	output logic [31:0] ex_mem_IR,
	output logic        ex_mem_valid_inst,
	
	
	// Outputs from MEM/WB Pipeline Register
	output logic [`XLEN-1:0] mem_wb_NPC,
	output logic [31:0] mem_wb_IR,
	output logic        mem_wb_valid_inst

);

	// Pipeline register enables
	logic if_id_enable, alu_wr_enable, ldst_wr_enable;
	
	// Outputs from IF-Stage
	logic [`XLEN-1:0] proc2Imem_addr;
	if_is_packet if_packet;

	// Outputs from IF/IS Pipeline Register
	if_is_packet if_is_packet;

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
	logic ROB_ENTRY rob_head_entry;             
	logic [`ROB_TAG_LEN-1:0] rob_head;
	logic rob_head_ready;

	// Outputs from Issue stage
	ID_EX_PACKET is_packet;
	logic ld_st_rs_enable, alu_rs_enable;
	logic [`XLEN-1:0] rob_alloc_store_value; 
	logic [`ROB_TAG_LEN-1:0] rob_alloc_store_dep_inst;
	logic rob_alloc_enable, rob_alloc_wr_mem, is_hazard;
    logic [`XLEN-1:0] rob_alloc_value_in;
    logic rob_alloc_value_in_valid;
	logic [2:0] rob_alloc_mem_size;
    logic [`ROB_TAG_LEN-1:0] rob_alloc_store_dep, is_rs1_rob_tag,  is_rs2_rob_tag,

	// Outputs from Reservation Stations
	INSTR_READY_ENTRY ld_st_rs_out, alu_rs_out;
	logic ld_st_rs_full, alu_rs_full;
	
	// Outputs from EX-Stage
	CDB_DATA alu_packet, acu_st_packet, lb_ex_packet;
	LB_PACKET acu_ld_packet;
	logic lb_read_mem, lb_full;
	logic [`ROB_TAG_LEN-1:0] lb_rob_tag;
	logic [`XLEN-1:0] lb_address;
	LB_PACKET lb_packet;


	// Outputs from EX/WR Pipeline Register
	CDB_DATA acu_wr_packet, lb_wr_packet, alu_wr_packet;

	// outputs from WR-Stage
	CDB_DATA cdb_data;
	logic acu_written, alu_written, load_written;

	// Outputs from mem unit
	logic [`XLEN-1:0] mem_result_out;
	logic [`XLEN-1:0] proc2Dmem_addr;
	logic [`XLEN-1:0] proc2Dmem_data;
	logic [1:0]  proc2Dmem_command;
	MEM_SIZE proc2Dmem_size;
	logic mem_busy;
	
	// Outputs from Commit-Stage  (These loop back to the register file in issue)
	COMMIT_PACKET commit_packet;	

	assign pipeline_completed_insts = {3'b0, commit_packet.valid};
	// todo: handle exceptions by passing them through ROB
	// assign pipeline_error_status =  mem_wb_illegal             ? ILLEGAL_INST :
	//                                 mem_wb_halt                ? HALTED_ON_WFI :
	//                                 (mem2proc_response==4'h0)  ? LOAD_ACCESS_FAULT :
	//                                 NO_ERROR;
	
	assign pipeline_commit_wr_idx = commit_packet.reg_wr_idx_out;
	assign pipeline_commit_wr_data = commit_packet.data_out;
	assign pipeline_commit_wr_en = commit_packet.reg_wr_en_out;
	// todo: pass NPC through ROB for pipeline printing
	// assign pipeline_commit_NPC = mem_wb_NPC;
	
	assign proc2mem_command =
	     (proc2Dmem_command == BUS_NONE) ? BUS_LOAD : proc2Dmem_command;
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
		.Imem2proc_data(mem2proc_data),
		
		// Outputs
		.proc2Imem_addr(proc2Imem_addr),
		.if_packet_out(if_packet)
	);


//////////////////////////////////////////////////
//                                              //
//            IF/ID Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign if_id_NPC        = if_is_packet.NPC;
	assign if_id_IR         = if_is_packet.inst;
	assign if_id_valid_inst = if_is_packet.valid;
	assign if_id_enable = 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin 
			if_is_packet.inst  <= `SD `NOP;
			if_is_packet.valid <= `SD `FALSE;
            if_is_packet.NPC   <= `SD 0;
            if_is_packet.PC    <= `SD 0;
		end else begin// if (reset)
			if (if_id_enable) begin
				if_is_packet <= `SD if_packet; 
			end // if (if_id_enable)	
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
		.alloc_enable(rob_alloc_enable),
		.alloc_wr_mem(rob_alloc_wr_mem),
		.alloc_value_in(rob_alloc_value_in),
		.alloc_store_dep(rob_alloc_store_dep_inst),
		.alloc_value_in_valid(rob_alloc_value_in_valid),
		.dest_reg(is_packet.dest_reg_idx),
		.alloc_mem_size(rob_alloc_mem_size),
		.read_rob_tag_rs1(map_table_packet_rs1.rob_tag_val),
		.read_rob_tag_rs2(map_table_packet_rs2.rob_tag_val),
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
//                  IS-Stage                    //
//                                              //
//////////////////////////////////////////////////
	
	maptable maptable_0 (
		//inputs
		.clock(clock),
		.reset(reset),
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
		
		// Outputs
		.id_packet_out(is_packet),
		.rs_enable(alu_rs_enable),
		.alloc_enable(rob_alloc_enable),
		.alloc_wr_mem(rob_alloc_wr_mem),
		.alloc_value_in(rob_alloc_value_in),
		.alloc_store_dep(rob_alloc_store_dep_inst),
		.alloc_value_in_valid(rob_alloc_value_in_valid),
		.alloc_mem_size(rob_alloc_mem_size),
		.rs1_rob_tag(is_rs1_rob_tag),
		.rs2_rob_tag(is_rs2_rob_tag),
		.stall_if(is_hazard)
	);

//////////////////////////////////////////////////
//                                              //
//           Reservation Stations               //
//                                              //
//////////////////////////////////////////////////


ReservationStation #(.NO_WAIT_RS2 = 1) ld_st_rs  (
	//inputs
	.clk(clock),
	.reset(reset),
	.cdb(cdb_data),
	.id_packet_out(is_packet),
	.maptable_packet_rs1(maptable_packet_rs1),
	.maptable_packet_rs2(maptable_packet_rs2),
	.alloc_slot(rob_alloc_slot),
	.alloc_enable(ld_st_rs_enable),
	// todo: handle execution stalls
	// .exec_stall(...)

	// outputs
	.rs_full(rs_st_ld_full),
	.ready_inst_entry(ready_inst_entry_st_ld)
);

ReservationStation #(.NO_WAIT_RS2 = 1) alu_rs  (
	//inputs
	.clk(clock),
	.reset(reset),
	.cdb(cdb_data),
	.id_packet_out(is_packet),
	.maptable_packet_rs1(maptable_packet_rs1),
	.maptable_packet_rs2(maptable_packet_rs2),
	.alloc_slot(rob_alloc_slot),
	.alloc_enable(alu_rs_enable),
	// todo: handle execution stalls
	// .exec_stall(...)

	// outputs
	.rs_full(alu_rs_full),
	.ready_inst_entry(ready_inst_entry_alu)
);


//////////////////////////////////////////////////
//                                              //
//                  EX-Stage                    //
//                                              //
//////////////////////////////////////////////////

alu_execution_unit alu_0 (
	// inputs
	.ready_inst_entry(ready_inst_entry_alu),
	// outputs
	.alu_cdb_output(alu_packet),
);

address_calculation_unit acu_0 (
	// inputs
	.ready_inst_entry(ready_inst_entry_st_ld),
	// outputs
	.store_result(acu_st_packet),
	.load_buffer_packet(acu_ld_packet)
);

load_buffer load_buffer_0 (
	// inputs
	.clock(clock),
	.reset(reset),
	.lb_packet_in(acu_ld_packet),
	// all reasons when lb should not alloc are handled by lb_packet_in and full
	.alloc_enable(1), 
	.pending_stores(pending_stores),
	// todo: likely a bug - loop from mem_busy to mem_command
	// mem_command none -> not busy -> mem_command load -> busy -> ...
	// should be handled together with mem structural hazard, considering IF as well
	.mem_busy(mem_busy),
	// outputs
	.lb_packet_out(lb_packet),
	.full(lb_full),
	.load_address(lb_address),
	.load_rob_tag(lb_rob_tag),
	.read_mem(lb_read_mem)
);	

// todo: there needs to be a load_ex stage that provides 
// the CDB data to WR stage (lb_ex_packet)

mem_stage mem_stage_0 (// Inputs
		.clock(clock),
		.reset(reset),
		.ex_mem_packet_in(ex_mem_packet),
		.Dmem2proc_data(mem2proc_data[`XLEN-1:0]),
		
		// Outputs
		.mem_result_out(mem_result_out),
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

	wr_stage wr_stage_0 (
		//inputs
		.clock(clock),
		.reset(reset),
		.ex_packet_in({acu_wr_packet,alu_wr_packet, lb_wr_packet}),
		// outputs
		.cdb(cdb_data),
		// todo: use written output in hazard detection
		.written({acu_written, alu_written, load_written})
	);

//////////////////////////////////////////////////
//                                              //
//              Commit-Stage                    //
//                                              //
//////////////////////////////////////////////////


	commit_stage commit_stage_0 (
		// inputs
		.clock(clock),
		.reset(reset),
		.head_entry(rob_head_entry),
		.commit_rob_tag(rob_head),
		// outputs
		.cmt_packet_out(commit_packet)
	);
endmodule  // module verisimple
`endif // __PIPELINE_V__
