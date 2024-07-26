/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  mem_stage.v                                         //
//                                                                     //
//  Description :  memory access (MEM) stage of the pipeline;          //
//                 this stage accesses memory for stores and loads,    // 
//                 and selects the proper next PC value for branches   // 
//                 based on the branch condition computed in the       //
//                 previous stage.                                     // 
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __MEM_STAGE_V__
`define __MEM_STAGE_V__

`timescale 1ns/100ps

module mem_stage(
	input         clock,              // system clock
	input         reset,              // system reset

	input  [`XLEN-1:0] Dmem2proc_data,	// input from system
	input [3:0] Dmem2proc_response,
	input [3:0] Dmem2proc_tag,


	input LB_PACKET lb_packet_in,			// from load buffer
	input logic  read_mem,					// form load buffer

	input COMMIT_PACKET  cmt_packet_in,	// from commit stage
	input lb_wr_enable,
	
	
	output mem_busy,					// to load buffer
	output Dmem_wait,					// to load buffer
	output Dmem_ready,
	
	output EX_WR_PACKET lb_ex_packet_out,
	output logic [1:0] proc2Dmem_command,
	output MEM_SIZE proc2Dmem_size,
	output logic [`XLEN-1:0] proc2Dmem_addr,      // Address sent to data-memory
	output logic [`XLEN-1:0] proc2Dmem_data      // Data sent to data-memory
);

	logic [`XLEN-1:0] mem_result_out;
	// State Definitions
	typedef enum logic [1:0] {
		READY,
		MEM_WAIT
	} Dmem_state;
	Dmem_state current_state, next_state;
	logic [3:0] recorded_response;
	logic Dmem_ready;

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
				if (!reset && !Dmem_ready && proc2Dmem_command == BUS_LOAD) begin
					next_state = MEM_WAIT;
				end
			end
			MEM_WAIT: begin
				if (Dmem_ready) begin
					next_state = READY;
				end			
			end
			default:
				next_state = READY;
		endcase
	end	
	
	initial begin
	   recorded_response = 0;
    end

	assign recorded_response = (proc2Dmem_command == BUS_LOAD)? Dmem2proc_response:recorded_response;
	assign Dmem_ready = (recorded_response !=0) && (recorded_response == Dmem2proc_tag);
	assign Dmem_wait = (next_state == MEM_WAIT);	
	
	assign lb_ex_packet_out.valid = (lb_packet_in.valid && Dmem_ready)?1:0;
	assign lb_ex_packet_out.NPC = lb_packet_in.NPC;
	assign lb_ex_packet_out.inst = lb_packet_in.inst;
	assign lb_ex_packet_out.rob_tag = lb_packet_in.rd_tag;
	assign lb_ex_packet_out.value = mem_result_out;

	// Determine the command that must be sent to mem
	assign proc2Dmem_command =
	                        (cmt_packet_in.wr_mem & cmt_packet_in.valid) ? BUS_STORE :
							(read_mem & lb_packet_in.valid & current_state == READY & lb_wr_enable) ? BUS_LOAD :
	                        BUS_NONE;

	assign proc2Dmem_size = proc2Dmem_command == BUS_LOAD 
		? MEM_SIZE'(lb_packet_in.mem_size[1:0]) 
		: MEM_SIZE'(cmt_packet_in.mem_size[1:0]);	//only the 2 LSB to determine the size;
	assign mem_busy = (proc2Dmem_command!=BUS_NONE);


	// The memory address is calculated by the ALU
	assign proc2Dmem_data = cmt_packet_in.data_out;

	assign proc2Dmem_addr = (proc2Dmem_command == BUS_LOAD) ? lb_packet_in.address : cmt_packet_in.mem_address;	
	// Assign the result-out for next stage
	always_comb begin
		mem_result_out = cmt_packet_in.data_out;
		if (read_mem) begin //read memory, load
			if (~cmt_packet_in.mem_size[2]) begin //is this an signed/unsigned load?
				if (proc2Dmem_size == 2'b0)
					mem_result_out = {{(`XLEN-8){Dmem2proc_data[7]}}, Dmem2proc_data[7:0]};
				else if  (proc2Dmem_size == 2'b01) 
					mem_result_out = {{(`XLEN-16){Dmem2proc_data[15]}}, Dmem2proc_data[15:0]};
				else mem_result_out = Dmem2proc_data;
			end else begin
				if (proc2Dmem_size == 2'b0)
					mem_result_out = {{(`XLEN-8){1'b0}}, Dmem2proc_data[7:0]};
				else if  (proc2Dmem_size == 2'b01)
					mem_result_out = {{(`XLEN-16){1'b0}}, Dmem2proc_data[15:0]};
				else mem_result_out = Dmem2proc_data;
			end
		end
	end
	//if we are in 32 bit mode, then we should never load a double word sized data
	assert property (@(negedge clock) (`XLEN == 32) && read_mem |-> proc2Dmem_size != DOUBLE);

endmodule // module mem_stage
`endif // __MEM_STAGE_V__
