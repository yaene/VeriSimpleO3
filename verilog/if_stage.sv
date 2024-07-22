/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  if_stage.v                                          //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       // 
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module if_stage(
	input         clock,                  // system clock
	input         reset,                  // system reset
	input         if_enable,              // should PC be updated
	input [`XLEN-1:0] ex_pc,                  // pc of instruction in ex
	input         ex_branch,              // is instruction in ex a branch
	input         ex_take_branch,         // for BPU update
	input         branch_misprediction,         // misprediction signal
	input  [`XLEN-1:0] ex_target_pc,        // target pc: use if misprediction is TRUE
	input  [63:0] Imem2proc_data,          // Data coming back from instruction-memory
	input  [3:0] Imem2proc_response,
	input  [3:0] Imem2proc_tag,
	input if_mem_hazard,

	output logic [`XLEN-1:0] proc2Imem_addr,    // Address sent to Instruction memory
	output logic [1:0] proc2Imem_command,
	output IF_ID_PACKET if_packet_out         // Output data packet from IF going to ID, see sys_defs for signal information 
);

	// State Definitions
	typedef enum logic [1:0] {
		READY,
		MEM_WAIT
	} state_t;

	state_t current_state, next_state;
	logic [3:0] recorded_response;

	logic [`XLEN-1:0] PC_reg;            // PC we are currently fetching
	
	logic [`XLEN-1:0] PC_plus_4;
	logic [`XLEN-1:0] next_PC;
	logic PC_enable;
	logic Imem_ready;
	logic predict_taken;
	logic [`XLEN-1:0] predict_target_pc;
	
	assign proc2Imem_addr = {PC_reg[`XLEN-1:3], 3'b0};

	// this mux is because the Imem gives us 64 bits not 32 bits
	assign if_packet_out.inst = PC_reg[2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];
	
	// default next PC value
	assign PC_plus_4 = PC_reg + 4;
	

	// misprediction signal must override stalling (otherwise it may be lost)
	assign PC_enable = if_enable | branch_misprediction;
	
	// Pass PC+4 down pipeline w/instruction
	assign if_packet_out.NPC = PC_plus_4;
	assign if_packet_out.PC  = PC_reg;
	assign if_packet_out.predict_taken = predict_taken;
	assign if_packet_out.predict_target_pc = predict_target_pc;

	branch_prediction_unit bpu_0 (
		.clock(clock),
		.reset(reset),
		.pc(PC_reg),
		.ex_pc(ex_pc),
		.ex_taken(ex_take_branch),
		.ex_branch(ex_branch),
		.ex_target_pc(ex_target_pc),
		.predict_taken(predict_taken),
		.predict_target_pc(predict_target_pc)
	);


	// next PC is target_pc if there is a taken branch or
	// PC predicted by branch prediction unit
	// the next sequential PC (PC+4) if predicted not taken
	always_comb begin
		next_PC = PC_plus_4;
		if(branch_misprediction) begin
			next_PC = ex_target_pc;
		end else if (predict_taken) begin
			next_PC = predict_target_pc;
		end
	end

	// State Transition Logic
	always_ff @(posedge clock) begin
		if (reset) begin
			current_state <= READY;
		end else begin
			current_state <= next_state;
		end
	end

	// State Transition Conditions
	always_comb begin
		next_state = current_state;
		case (current_state)
			READY: begin
				if (!reset && PC_enable && !Imem_ready && !if_mem_hazard) begin
					next_state = MEM_WAIT;
				end
			end
			MEM_WAIT: begin
				if (Imem_ready || branch_misprediction) begin
					next_state = READY;
				end			
			end
			default:
				next_state = READY;
		endcase
	end

	// Output Logic
	always_ff @(posedge clock or posedge reset) begin
		if (reset) begin
			PC_reg <= `SD 0;
		end else begin
			if ((PC_enable && Imem_ready) || branch_misprediction) begin
				PC_reg <= `SD next_PC; // transition to next PC
			end
		end
	end

	assign recorded_response = (proc2Imem_command == BUS_LOAD)? Imem2proc_response:recorded_response;
	assign Imem_ready = (recorded_response !=0) && (recorded_response == Imem2proc_tag);
	assign proc2Imem_command = (!reset && PC_enable && current_state == READY && !if_mem_hazard)? BUS_LOAD : BUS_NONE;
	assign if_packet_out.valid = Imem_ready;

endmodule  // module if_stage
