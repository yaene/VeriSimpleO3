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
	input         ex_take_branch,         // taken-branch signal
	input  [`XLEN-1:0] ex_target_pc,        // target pc: use if take_branch is TRUE
	input  [63:0] Imem2proc_data,          // Data coming back from instruction-memory
	input  [3:0] Imem2proc_response,
	input  [3:0] Imem2proc_tag,

	output logic [`XLEN-1:0] proc2Imem_addr,    // Address sent to Instruction memory
	output logic [1:0] proc2Imem_command,
	output IF_ID_PACKET if_packet_out         // Output data packet from IF going to ID, see sys_defs for signal information 
);

	// State Definitions
	typedef enum logic [1:0] {
		IDLE,
		REQUEST,
		MEM_WAIT
	} state_t;

	state_t current_state, next_state;
	logic [3:0] recorded_response;

	logic [`XLEN-1:0] PC_reg;            // PC we are currently fetching
	
	logic [`XLEN-1:0] PC_plus_4;
	logic [`XLEN-1:0] next_PC;
	logic PC_enable;
	
	assign proc2Imem_addr = {PC_reg[`XLEN-1:3], 3'b0};

	// this mux is because the Imem gives us 64 bits not 32 bits
	assign if_packet_out.inst = PC_reg[2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];
	
	// default next PC value
	assign PC_plus_4 = PC_reg + 4;
	
	// next PC is target_pc if there is a taken branch or
	// the next sequential PC (PC+4) if no branch
	// (halting is handled with the enable PC_enable;
	assign next_PC = ex_take_branch ? ex_target_pc : PC_plus_4;
	
	// The take-branch signal must override stalling (otherwise it may be lost)
	assign PC_enable = if_enable | ex_take_branch;
	
	// Pass PC+4 down pipeline w/instruction
	assign if_packet_out.NPC = PC_plus_4;
	assign if_packet_out.PC  = PC_reg;

	// State Transition Logic
	always_ff @(posedge clock) begin
		if (reset) begin
			current_state <= IDLE;
		end else begin
			current_state <= next_state;
		end
	end

	// State Transition Conditions
	always_comb begin
		next_state = current_state;
		proc2Imem_command = BUS_NONE;
		if_packet_out.valid = 0;
		case (current_state)
			IDLE: begin
				if (!reset && PC_enable) begin
					proc2Imem_command = BUS_LOAD;
					recorded_response = Imem2proc_response;
					if (Imem2proc_response != Imem2proc_tag) begin
						next_state = MEM_WAIT;
					end
					else begin
						next_state = REQUEST;
						if_packet_out.valid = 1;
					end
				end
			end
			REQUEST: begin
				if (PC_enable) begin
					proc2Imem_command = BUS_LOAD;
					recorded_response = Imem2proc_response;
					if (Imem2proc_response != Imem2proc_tag) begin
						next_state = MEM_WAIT;
					end
					else begin
						if_packet_out.valid = 1;
					end
				end
				else begin
					next_state = IDLE;
				end				
			end
			MEM_WAIT: begin
				proc2Imem_command = BUS_NONE;
				if (Imem2proc_tag == recorded_response) begin
					next_state = REQUEST;
					if_packet_out.valid = 1;
				end
			end
		endcase
	end

	// Output Logic
	always_ff @(posedge clock or posedge reset) begin
		if (reset) begin
			PC_reg <= `SD 0;
		end else begin
			if (PC_enable && current_state != MEM_WAIT) begin
				PC_reg <= `SD next_PC; // transition to next PC
			end
		end
	end

endmodule  // module if_stage
